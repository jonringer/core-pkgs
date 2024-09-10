/* List of maintainer teams.
    name = {
      # Required
      members = [ maintainer1 maintainer2 ];
      scope = "Maintain foo packages.";
      shortName = "foo";
      # Optional
      enableFeatureFreezePing = true;
      githubTeams = [ "my-subsystem" ];
    };

  where

  - `members` is the list of maintainers belonging to the group,
  - `scope` describes the scope of the group.
  - `shortName` short human-readable name
  - `enableFeatureFreezePing` will ping this team during the Feature Freeze announcements on releases
    - There is limited mention capacity in a single post, so this should be reserved for critical components
      or larger ecosystems within nixpkgs.
  - `githubTeams` will ping specified GitHub teams as well

  More fields may be added in the future.

  When editing this file:
   * keep the list alphabetically sorted
   * test the validity of the format with:
       nix-build lib/tests/teams.nix
  */

{ lib }:
with lib.maintainers; {

  python = {
    members = [
      jonringer
    ];
    scope = "Maintain python ecosystem and packages";
    shortName = "python";
    enableFeatureFreezePing = true;
  };

}

