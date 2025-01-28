import hwylterm, hwylterm/hwylcli

proc hwylCliError*(msg: string) =
  stderr.write "override the default error\n"
  quit $(bb("error ", "red") & bb(msg))

hwylCli:
  name "base"
  run:
    echo "a base cli"
