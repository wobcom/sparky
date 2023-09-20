{ ... }:

{
  config = {
    users.users.support = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # user with password, can for example be used for serial connections to the probe
      hashedPassword = "some password hash";
    };

    users.users.example-ssh-user = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # user with ssh pubkey
      openssh.authorizedKeys.keys = [ "your pubkey here" ];
    };
  };
}