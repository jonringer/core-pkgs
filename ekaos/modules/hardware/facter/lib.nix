# Internal library functions for hardware.facter modules
# Helpers for querying nixos-facter reports
lib:
let
  inherit (lib) assertMsg;

  # Query if a facter report contains a CPU with the given vendor name
  hasCpu =
    name:
    {
      hardware ? { },
      ...
    }:
    let
      cpus = hardware.cpu or [ ];
    in
    assert assertMsg (hardware != { }) "no hardware entries found in the report";
    assert assertMsg (cpus != [ ]) "no cpu entries found in the report";
    builtins.any (
      {
        vendor_name ? null,
        ...
      }:
      assert assertMsg (vendor_name != null) "detail.vendor_name not found in cpu entry";
      vendor_name == name
    ) cpus;

  # Extract all driver_modules from a list of hardware entries
  collectDrivers = list: lib.foldl' (lst: value: lst ++ value.driver_modules or [ ]) [ ] list;

  # Deduplicate a list of strings
  stringSet = list: builtins.attrNames (builtins.groupBy lib.id list);

  # Query if a facter report contains a GPU with the given PCI vendor ID
  hasGpuVendor =
    vendorId:
    {
      hardware ? { },
      ...
    }:
    builtins.any (
      {
        vendor ? { },
        ...
      }:
      (vendor.value or 0) == vendorId
    ) (hardware.graphics_card or [ ]);

  # Check if facter report indicates a portable/laptop chassis via SMBIOS
  # SMBIOS chassis types: 8=Portable, 9=Laptop, 10=Notebook,
  # 14=Sub Notebook, 30=Tablet, 31=Convertible, 32=Detachable
  isPortableChassis =
    {
      smbios ? { },
      ...
    }:
    let
      portableTypes = [
        8
        9
        10
        14
        30
        31
        32
      ];
    in
    builtins.any (
      {
        chassis_type ? { },
        ...
      }:
      builtins.elem (chassis_type.value or 0) portableTypes
    ) (smbios.chassis or [ ]);

  # Convert number to zero-padded 4-digit hex string (for USB device IDs)
  toZeroPaddedHex =
    n:
    let
      hex = lib.toHexString n;
      len = builtins.stringLength hex;
    in
    if len == 1 then
      "000${hex}"
    else if len == 2 then
      "00${hex}"
    else if len == 3 then
      "0${hex}"
    else
      hex;
  # SMBIOS vendor/product matching for device quirks
  hasManufacturer =
    name:
    {
      smbios ? { },
      ...
    }:
    lib.hasInfix name ((smbios.system or { }).manufacturer or "");

  hasProduct =
    pattern:
    {
      smbios ? { },
      ...
    }:
    lib.hasInfix pattern ((smbios.system or { }).product_name or "");

  isDevice =
    {
      manufacturer,
      product ? null,
    }:
    report: hasManufacturer manufacturer report && (product == null || hasProduct product report);

  # Query if a facter report contains a PCI device with the given vendor and device IDs
  hasPciDevice =
    vendorId: deviceId:
    {
      hardware ? { },
      ...
    }:
    let
      allPci =
        (hardware.graphics_card or [ ])
        ++ (hardware.network_controller or [ ])
        ++ (hardware.storage_controller or [ ])
        ++ (hardware.multimedia_controller or [ ]);
    in
    builtins.any (
      {
        vendor ? { },
        device ? { },
        ...
      }:
      (vendor.value or 0) == vendorId && (device.value or 0) == deviceId
    ) allPci;

  # Query if a facter report contains a USB device with the given vendor ID
  hasUsbVendor =
    vendorId:
    {
      hardware ? { },
      ...
    }:
    let
      allUsb =
        (hardware.fingerprint_reader or [ ])
        ++ (hardware.joystick or [ ])
        ++ (hardware.scanner or [ ])
        ++ (hardware.printer or [ ]);
    in
    builtins.any (
      {
        vendor ? { },
        ...
      }:
      (vendor.value or 0) == vendorId
    ) allUsb;

  # Check if the facter report indicates a convertible/tablet chassis
  # SMBIOS: 30=Tablet, 31=Convertible, 32=Detachable
  isConvertibleChassis =
    {
      smbios ? { },
      ...
    }:
    builtins.any (
      {
        chassis_type ? { },
        ...
      }:
      builtins.elem (chassis_type.value or 0) [
        30
        31
        32
      ]
    ) (smbios.chassis or [ ]);
in
{
  inherit
    hasCpu
    hasGpuVendor
    isPortableChassis
    collectDrivers
    stringSet
    toZeroPaddedHex
    hasManufacturer
    hasProduct
    isDevice
    hasPciDevice
    hasUsbVendor
    isConvertibleChassis
    ;

  hasAmdCpu = hasCpu "AuthenticAMD";
  hasIntelCpu = hasCpu "GenuineIntel";

  # PCI vendor IDs: AMD/ATI=0x1002, Intel=0x8086, NVIDIA=0x10de
  hasAmdGpu = hasGpuVendor 4098;
  hasIntelGpu = hasGpuVendor 32902;
  hasNvidiaGpu = hasGpuVendor 4318;

  # Common device checks
  isFramework = hasManufacturer "Framework";
  isSurface = isDevice {
    manufacturer = "Microsoft Corporation";
    product = "Surface";
  };
  isThinkPad = hasProduct "ThinkPad";
  isAsusRog = isDevice {
    manufacturer = "ASUSTeK";
    product = "ROG";
  };
  isDellXps = isDevice {
    manufacturer = "Dell";
    product = "XPS";
  };
}
