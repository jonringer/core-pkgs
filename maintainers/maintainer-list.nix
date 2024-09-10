/*
  List of NixOS maintainers.
   ```nix
   handle = {
     # Required
     name = "Your name";

     # Optional, but at least one of email, matrix or githubId must be given
     email = "address@example.org";
     matrix = "@user:example.org";
     github = "GithubUsername";
     githubId = your-github-id;

     keys = [{
       fingerprint = "AAAA BBBB CCCC DDDD EEEE  FFFF 0000 1111 2222 3333";
     }];
   };
   ```

   where

   - `handle` is the handle you are going to use in nixpkgs expressions,
   - `name` is a name that people would know and recognize you by,
   - `email` is your maintainer email address,
   - `matrix` is your Matrix user ID,
   - `github` is your GitHub handle (as it appears in the URL of your profile page, `https://github.com/<userhandle>`),
   - `githubId` is your GitHub user ID, which can be found at `https://api.github.com/users/<userhandle>`,
   - `keys` is a list of your PGP/GPG key fingerprints.

   Specifying a GitHub account ensures that you automatically:
   - get invited to the @NixOS/nixpkgs-maintainers team ;
   - once you are part of the @NixOS org, OfBorg will request you review
     pull requests that modify a package for which you are a maintainer.

   `handle == github` is strongly preferred whenever `github` is an acceptable attribute name and is short and convenient.

   If `github` begins with a numeral, `handle` should be prefixed with an underscore.
   ```nix
   _1example = {
     github = "1example";
   };
   ```

   Add PGP/GPG keys only if you actually use them to sign commits and/or mail.

   To get the required PGP/GPG values for a key run
   ```shell
   gpg --fingerprint <email> | head -n 2
   ```

   !!! Note that PGP/GPG values stored here are for informational purposes only, don't use this file as a source of truth.

   More fields may be added in the future, however, in order to comply with GDPR this file should stay as minimal as possible.

   When editing this file:
    * keep the list alphabetically sorted, check with:
        nix-instantiate --eval maintainers/scripts/check-maintainers-sorted.nix
    * test the validity of the format with:
        nix-build lib/tests/maintainers.nix

   See `./scripts/check-maintainer-github-handles.sh` for an example on how to work with this data.

   When adding a new maintainer, be aware of the current commit conventions
   documented at [CONTRIBUTING.md](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#commit-conventions)
   file located in the root of the Nixpkgs repo.
*/
{
  jonringer = {
    email = "jonringer117@gmail.com";
    matrix = "@jonringer:matrix.org";
    github = "jonringer";
    githubId = 7673602;
    name = "Jonathan Ringer";
  };
}

