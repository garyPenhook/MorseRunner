# Bundled contest callsign data

`MASTER.SCP` is an unmodified snapshot of Super Check Partial's public contest
callsign list, retrieved on 2026-08-10 from
<https://supercheckpartial.com/MASTER.SCP>. It is included so a fresh source
checkout has a realistic worldwide caller population without requiring a
network connection.

The source remains attributable to Super Check Partial. Keep its header and
update the source URL and retrieval date whenever the snapshot is replaced.
Users can install a newer user-owned copy at
`$XDG_DATA_HOME/morserunner/MASTER.SCP` with `make update-call-list`; the user
copy takes precedence over this development snapshot.
