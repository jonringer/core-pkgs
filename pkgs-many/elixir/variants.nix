{
  v1_17 = {
    version = "1.17.3";
    # Elixir 1.17 (Compatible with OTP 25-27)
    src-hash = "sha256-YRbBTV5h7DASQM6+rL+elxJaTUXNkHHmXguVjV6/OJA=";
    minimumOTPVersion = "25";
    # The default erlang (v27) is actually OTP 29, which is incompatible.
    # Pin to erlang v26 (OTP 26) which is within the supported range.
    erlangVariant = "v26";
  };

  v1_18 = {
    version = "1.18.1";
    # Elixir 1.18+ requires OTP 27+
    src-hash = "sha256-QjWmPGFcfHh9haUWfbKKWOyfWlefmz/YU/xvTYhsIJ4=";
    minimumOTPVersion = "27";
    # The default erlang (v27) is actually OTP 29, which is incompatible.
    # Pin to erlang v28 (OTP 28) which satisfies the OTP 27+ requirement.
    erlangVariant = "v28";
  };
}
