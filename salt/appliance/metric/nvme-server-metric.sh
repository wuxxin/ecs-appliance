#!/bin/bash

output_format_awk="$(cat << 'OUTPUTAWK'
BEGIN { v = "" }
v != $1 {
  print "# HELP nvme_" $1 " NVME metric " $1;
  print "# TYPE nvme_" $1 " gauge";
  v = $1
}
{print "nvme_" $0}
OUTPUTAWK
)"

format_output() {
  sort | awk -F'{' "${output_format_awk}"
}

nvme_version=$(nvme version | head -n1 | grep version | \
    sed -r "s/.*version ([0-9\.]+).*/\1/")
echo "version{version=\"$nvme_version\"} 1" | format_output

device_list=$(nvme list | grep "^/dev" | sed -r "s#(/dev[^ ]+).*#\1#")
for device in ${device_list}; do
    nvme_ctrl_info=$(nvme id-ctrl $device)
    device_model=$(echo "$nvme_ctrl_info" |
        grep -E "^mn[ \t]+:" | sed -r "s/[^:]+: ([^ ]+).*/\1/")
    model_family=$(echo "$nvme_ctrl_info" |
        grep -E "^mn[ \t]+:" | sed -r "s/[^:]+: [^ ]+ ([^ ]*).*/\1/")
    firmware_version=$(echo "$nvme_ctrl_info" |
        grep -E "^fr[ \t]+:" |  sed -r "s/[^:]+: (.*)/\1/")
    serial_number_hex=$(nvme id-ns ${device} |
        grep "^eui64" | sed -r "s/[^:]+: (.*)/\1/")
    serial_number=$(python -c "print(int(\"$serial_number_hex\", 16))")
    echo "device_info{disk=\"$device\",type=\"nvme\",model_family=\"$model_family\",device_model=\"$device_model\",serial_number=\"$serial_number_hex\",firmware_version=\"$firmware_version\"} 1"

    nvme smart-log $device | sed '1d' | tr "A-Z" "a-z" | sed -r "s/(([a-z0-9_]+ ?)+) +: ([0-9,]+).*/\1#\3/g" | sed -r "s/(.*) (#.*)/\1\2/g" | tr -d "," | tr " #" "_ " | sed -r "s#([^ ]+) +([^ ]+) *#\1\{device=\"$device\"\} \2#g" | sed -r "s/^(available_spare)(.*)/\1_percentage\2/g"

done | format_output
