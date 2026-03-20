##[
  .. importdoc:: ./hwylterm/spin/spinners
  .. importdoc:: ./hwylterm/progress

  # Hwylterm

  see also these utility modules:

  | module | description |
  |---|---|
  | [hwylcli](./hwylterm/hwylcli.html) | macro to generate CLI's styled by bbansi and with parsing parseopt3 |
  | [chooser](./hwylterm/chooser.html) | simple scrolling multi-item selecter |
  | [logging](./hwylterm/logging.html) | wrapper for std/logging with styling |

  .. include:: ./docs/bbansi.md
  .. include:: ./docs/confirm.md
  .. include:: ./docs/spin.md
  .. include:: ./docs/progress.md
]##


import hwylterm/[spin, bbansi, confirm, progress]
export spin, bbansi, confirm, progress
