{ ... }:

{
  services.quillHermes = {
    enable = true;
    user = "quill";
    group = "users";
    homeDirectory = "/home/quill";
    enableGatewayService = true;
  };
}
