{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.vim
    pkgs.git
    pkgs.tmux
    pkgs.htop
    pkgs.btop

    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
    pkgs.tree
    pkgs.unzip

    pkgs.curl
    pkgs.wget
    pkgs.dig
    pkgs.whois

    pkgs.mcrcon
    pkgs.claude-code
  ];

  programs.bash.completion.enable = true;
}
