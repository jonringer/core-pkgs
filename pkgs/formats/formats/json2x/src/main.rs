use std::{
    fs::{read_to_string, write},
    io::Write,
    path::PathBuf,
};

use anyhow::{Context, bail};
use argh::{FromArgValue, FromArgs};
use quick_xml::{
    Writer,
    escape::partial_escape,
    events::{BytesDecl, BytesEnd, BytesStart, BytesText, Event},
};
use serde_json::{Map, Value};

/// Convert a JSON file to another format
#[derive(FromArgs)]
struct Args {
    /// convert only value of this attribute
    #[argh(option)]
    unwrap: Option<String>,
    /// omit the XML declaration
    #[argh(switch)]
    no_header: bool,
    /// format of the output file, possible values: toml, xml
    #[argh(positional)]
    format: Format,
    /// path to the input file
    #[argh(positional)]
    input: PathBuf,
    /// path to the output file
    #[argh(positional)]
    output: PathBuf,
}

#[derive(FromArgValue)]
enum Format {
    Toml,
    Xml,
}

fn main() -> anyhow::Result<()> {
    let args: Args = argh::from_env();
    if args.no_header && !matches!(args.format, Format::Xml) {
        bail!("--no-header is only valid for XML output");
    }

    let json_text = read_to_string(&args.input)
        .with_context(|| format!("failed to read {}", args.input.display()))?;
    let parsed_json: serde_json::Value = serde_json::from_str(&json_text)
        .with_context(|| format!("failed to parse {}", args.input.display()))?;
    let output_value = if let Some(unwrap_key) = args.unwrap {
        parsed_json
            .as_object()
            .ok_or_else(|| anyhow::anyhow!("{} does not contain an object", args.input.display()))?
            .get(&unwrap_key)
            // The key is missing from structured attrs when the value is null, treat missing value as Value::Null.
            .unwrap_or(&serde_json::Value::Null)
    } else {
        &parsed_json
    };

    let output = match args.format {
        Format::Toml => toml::to_string(output_value)
            .context("failed to serialize value to toml")?
            .into_bytes(),
        Format::Xml => {
            let mut output = Vec::new();
            write_xml(&mut output, output_value, !args.no_header)
                .context("failed to serialize value to XML")?;
            output
        }
    };
    write(&args.output, output)
        .with_context(|| format!("failed to write {}", args.output.display()))?;

    Ok(())
}

// This implements the historical nixpkgs "badgerfish" format, which follows
// xmltodict: text is stored under `#text` (not BadgerFish's `$`) and scalar
// element values can be written directly.
fn write_xml<W: Write>(output: W, value: &Value, with_header: bool) -> anyhow::Result<()> {
    let document = value.as_object().context("XML value must be an object")?;

    let roots = document
        .iter()
        .filter(|(name, _)| name.as_str() != "#comment")
        .map(|(_, value)| match value {
            Value::Array(values) => values.len(),
            _ => 1,
        })
        .sum::<usize>();
    if roots != 1 {
        bail!("XML document must have exactly one root element");
    }

    let mut writer = Writer::new(output);
    if with_header {
        writer.write_event(Event::Decl(BytesDecl::new("1.0", Some("utf-8"), None)))?;
        write_whitespace(&mut writer, "\n")?;
    }

    for (name, value) in document {
        write_entry(&mut writer, name, value, 0)?;
    }
    write_whitespace(&mut writer, "\n")?;

    Ok(())
}

fn write_entry<W: Write>(
    writer: &mut Writer<W>,
    name: &str,
    value: &Value,
    depth: usize,
) -> anyhow::Result<()> {
    if name == "#comment" {
        return write_comments(writer, value, depth);
    }

    if let Value::Array(values) = value {
        for value in values {
            write_element(writer, name, value, depth)?;
        }
    } else {
        write_element(writer, name, value, depth)?;
    }

    Ok(())
}

fn write_element<W: Write>(
    writer: &mut Writer<W>,
    name: &str,
    value: &Value,
    depth: usize,
) -> anyhow::Result<()> {
    validate_name(name, "element")?;
    let element = match value {
        Value::Null => Element::default(),
        Value::Object(object) => split_element(object)?,
        Value::Array(_) => {
            bail!("nested lists are not supported; lists can only repeat named XML elements")
        }
        value => Element {
            text: Some(xml_scalar(value, "XML element value")?),
            ..Element::default()
        },
    };

    write_indent(writer, depth)?;
    let mut start = BytesStart::new(name);
    for (name, value) in &element.attributes {
        validate_xml_characters(value, "attribute value")?;
        start.push_attribute((name.as_str(), value.as_str()));
    }
    writer.write_event(Event::Start(start))?;

    if !element.children.is_empty() {
        write_whitespace(writer, "\n")?;
    }
    for (name, value) in &element.children {
        write_entry(writer, name, value, depth + 1)?;
    }
    if let Some(text) = element.text {
        validate_xml_characters(&text, "text")?;
        writer.write_event(Event::Text(BytesText::from_escaped(partial_escape(&text))))?;
    }
    if !element.children.is_empty() {
        write_indent(writer, depth)?;
    }

    writer.write_event(Event::End(BytesEnd::new(name)))?;
    if depth > 0 {
        write_whitespace(writer, "\n")?;
    }
    Ok(())
}

#[derive(Default)]
struct Element<'a> {
    attributes: Vec<(String, String)>,
    children: Vec<(&'a str, &'a Value)>,
    text: Option<String>,
}

fn split_element(object: &Map<String, Value>) -> anyhow::Result<Element<'_>> {
    let mut element = Element::default();

    for (name, value) in object {
        if name == "#text" {
            if !value.is_null() {
                element.text = Some(xml_scalar(value, "XML #text value")?);
            }
        } else if name == "@xmlns" && value.is_object() {
            for (prefix, uri) in value.as_object().expect("checked above") {
                if !prefix.is_empty() {
                    validate_name(prefix, "attribute")?;
                }
                let name = if prefix.is_empty() {
                    "xmlns".to_owned()
                } else {
                    format!("xmlns:{prefix}")
                };
                element
                    .attributes
                    .push((name, xml_scalar(uri, "XML namespace URI")?));
            }
        } else if let Some(name) = name.strip_prefix('@') {
            validate_name(name, "attribute")?;
            element
                .attributes
                .push((name.to_owned(), xml_scalar(value, "XML attribute value")?));
        } else if !matches!(value, Value::Array(values) if values.is_empty()) {
            element.children.push((name.as_str(), value));
        }
    }

    Ok(element)
}

fn write_comments<W: Write>(
    writer: &mut Writer<W>,
    value: &Value,
    depth: usize,
) -> anyhow::Result<()> {
    let comments = match value {
        Value::Array(values) => values.as_slice(),
        value => std::slice::from_ref(value),
    };

    for comment in comments {
        if comment.is_null() {
            continue;
        }
        let comment = match comment {
            Value::String(comment) => comment,
            _ => bail!("XML comments must be strings or null"),
        };
        if comment.is_empty() {
            continue;
        }
        if comment.contains("--") || comment.ends_with('-') {
            bail!("invalid XML comment");
        }
        validate_xml_characters(comment, "comment")?;
        write_indent(writer, depth)?;
        writer.write_event(Event::Comment(BytesText::from_escaped(partial_escape(
            comment,
        ))))?;
        write_whitespace(writer, "\n")?;
    }

    Ok(())
}

fn validate_name(name: &str, kind: &str) -> anyhow::Result<()> {
    let mut characters = name.chars();
    if !characters.next().is_some_and(is_xml_name_start) || !characters.all(is_xml_name_character) {
        bail!("invalid XML {kind} name: {name:?}");
    }
    Ok(())
}

fn is_xml_name_start(character: char) -> bool {
    matches!(
        character,
        ':' | 'A'..='Z'
            | '_'
            | 'a'..='z'
            | '\u{c0}'..='\u{d6}'
            | '\u{d8}'..='\u{f6}'
            | '\u{f8}'..='\u{2ff}'
            | '\u{370}'..='\u{37d}'
            | '\u{37f}'..='\u{1fff}'
            | '\u{200c}'..='\u{200d}'
            | '\u{2070}'..='\u{218f}'
            | '\u{2c00}'..='\u{2fef}'
            | '\u{3001}'..='\u{d7ff}'
            | '\u{f900}'..='\u{fdcf}'
            | '\u{fdf0}'..='\u{fffd}'
            | '\u{10000}'..='\u{effff}'
    )
}

fn is_xml_name_character(character: char) -> bool {
    is_xml_name_start(character)
        || matches!(
            character,
            '-' | '.' | '0'..='9' | '\u{b7}' | '\u{300}'..='\u{36f}' | '\u{203f}'..='\u{2040}'
        )
}

fn validate_xml_characters(value: &str, kind: &str) -> anyhow::Result<()> {
    if value.chars().any(|character| {
        !matches!(
            character as u32,
            0x9 | 0xa | 0xd | 0x20..=0xd7ff | 0xe000..=0xfffd | 0x10000..=0x10ffff
        )
    }) {
        bail!("invalid XML character in {kind}");
    }
    Ok(())
}

fn write_indent<W: Write>(writer: &mut Writer<W>, depth: usize) -> anyhow::Result<()> {
    for _ in 0..depth {
        write_whitespace(writer, "  ")?;
    }
    Ok(())
}

fn write_whitespace<W: Write>(writer: &mut Writer<W>, value: &str) -> anyhow::Result<()> {
    writer.write_event(Event::Text(BytesText::new(value)))?;
    Ok(())
}

fn xml_scalar(value: &Value, context: &str) -> anyhow::Result<String> {
    match value {
        Value::Null => Ok(String::new()),
        Value::Bool(value) => Ok(value.to_string()),
        Value::Number(value) => Ok(value.to_string()),
        Value::String(value) => Ok(value.clone()),
        Value::Array(_) | Value::Object(_) => bail!("{context} must be a scalar or null"),
    }
}

#[cfg(test)]
mod tests {
    use super::write_xml;
    use serde_json::json;

    #[test]
    fn writes_xmltodict_compatible_mapping() {
        let mut output = Vec::new();
        write_xml(
            &mut output,
            &json!({
                "root": {
                    "@class": "example",
                    "@id": "123",
                    "child1": { "@name": "child1Name", "#text": "text node" },
                    "child2": { "grandchild": "This is a grandchild text node." },
                    "nulltest": null
                }
            }),
            true,
        )
        .unwrap();

        assert_eq!(
            String::from_utf8(output).unwrap(),
            concat!(
                "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n",
                "<root class=\"example\" id=\"123\">\n",
                "  <child1 name=\"child1Name\">text node</child1>\n",
                "  <child2>\n",
                "    <grandchild>This is a grandchild text node.</grandchild>\n",
                "  </child2>\n",
                "  <nulltest></nulltest>\n",
                "</root>\n",
            )
        );
    }

    #[test]
    fn writes_lists_namespaces_comments_and_escaped_text() {
        let mut output = Vec::new();
        write_xml(
            &mut output,
            &json!({
                "#comment": "before & <root>",
                "root": {
                    "@xmlns": { "": "urn:default", "x": "urn:x" },
                    "@special": "<&\"'>",
                    "item": [true, false, null, "<&>"],
                    "omitted": []
                }
            }),
            false,
        )
        .unwrap();

        assert_eq!(
            String::from_utf8(output).unwrap(),
            concat!(
                "<!--before &amp; &lt;root&gt;-->\n",
                "<root special=\"&lt;&amp;&quot;&apos;&gt;\" xmlns=\"urn:default\" xmlns:x=\"urn:x\">\n",
                "  <item>true</item>\n",
                "  <item>false</item>\n",
                "  <item></item>\n",
                "  <item>&lt;&amp;&gt;</item>\n",
                "</root>\n",
            )
        );
    }

    #[test]
    fn rejects_multiple_roots() {
        let error = write_xml(Vec::new(), &json!({ "one": {}, "two": {} }), true).unwrap_err();
        assert_eq!(
            error.to_string(),
            "XML document must have exactly one root element"
        );
    }

    #[test]
    fn rejects_name_injection() {
        let error =
            write_xml(Vec::new(), &json!({ "root></root><injected": {} }), true).unwrap_err();
        assert_eq!(
            error.to_string(),
            "invalid XML element name: \"root></root><injected\""
        );
    }

    #[test]
    fn rejects_invalid_names_and_characters() {
        assert!(write_xml(Vec::new(), &json!({ "1root": {} }), true).is_err());
        assert!(write_xml(Vec::new(), &json!({ "root": { "@": "value" } }), true).is_err());
        assert!(write_xml(Vec::new(), &json!({ "root": "bad\u{1}text" }), true).is_err());
    }

    #[test]
    fn rejects_values_without_an_xml_representation() {
        let error = write_xml(
            Vec::new(),
            &json!({ "root": { "values": [[1, 2]] } }),
            false,
        )
        .unwrap_err();
        assert_eq!(
            error.to_string(),
            "nested lists are not supported; lists can only repeat named XML elements"
        );

        let error = write_xml(
            Vec::new(),
            &json!({ "root": { "@attribute": { "nested": true } } }),
            false,
        )
        .unwrap_err();
        assert_eq!(
            error.to_string(),
            "XML attribute value must be a scalar or null"
        );

        let error = write_xml(
            Vec::new(),
            &json!({ "root": { "#text": ["one", "two"] } }),
            false,
        )
        .unwrap_err();
        assert_eq!(
            error.to_string(),
            "XML #text value must be a scalar or null"
        );

        let error =
            write_xml(Vec::new(), &json!({ "#comment": true, "root": {} }), false).unwrap_err();
        assert_eq!(error.to_string(), "XML comments must be strings or null");
    }
}
