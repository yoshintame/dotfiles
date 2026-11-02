textfile_dir="$1"
output="$textfile_dir/mac.prom"
temporary="$(mktemp "$output.tmp.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

battery_field() {
  /usr/sbin/ioreg -r -c AppleSmartBattery -d 1 |
    sed -n "s/^[[:space:]]*\"$1\" = \([0-9][0-9]*\)$/\1/p" |
    head -n 1
}

{
  echo '# HELP mac_memory_pressure_level Kernel memory pressure level: 1 normal, 2 warning, 4 critical.'
  echo '# TYPE mac_memory_pressure_level gauge'
  echo "mac_memory_pressure_level $(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level)"
  echo '# HELP mac_memory_free_ratio Share of memory the kernel considers available.'
  echo '# TYPE mac_memory_free_ratio gauge'
  echo "mac_memory_free_ratio $(/usr/sbin/sysctl -n kern.memorystatus_level | awk '{ print $1 / 100 }')"

  cycles="$(battery_field CycleCount)"
  if [ -n "$cycles" ]; then
    echo '# HELP mac_battery_cycle_count Battery charge cycle count.'
    echo '# TYPE mac_battery_cycle_count gauge'
    echo "mac_battery_cycle_count $cycles"
    echo '# HELP mac_battery_full_charge_capacity_mah Current full charge capacity.'
    echo '# TYPE mac_battery_full_charge_capacity_mah gauge'
    echo "mac_battery_full_charge_capacity_mah $(battery_field NominalChargeCapacity)"
    echo '# HELP mac_battery_design_capacity_mah Design capacity.'
    echo '# TYPE mac_battery_design_capacity_mah gauge'
    echo "mac_battery_design_capacity_mah $(battery_field DesignCapacity)"
  fi
} >"$temporary"

chmod 0644 "$temporary"
mv "$temporary" "$output"
trap - EXIT
