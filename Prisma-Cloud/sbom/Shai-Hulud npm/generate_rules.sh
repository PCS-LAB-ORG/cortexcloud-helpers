# usage: bash generate_rules.sh input_list.txt output.json
#!/usr/bin/env bash
input="$1"
output="$2"

rules=()

while IFS= read -r line; do
  for part in $(echo "$line" | tr ',' '\n'); do
    pkg=$(echo "$part" | sed -E 's/^([^@]*@)?([^@]+)@.*/\1\2/')
    ver=$(echo "$part" | sed -E 's/.*@//')
    name="npm_${pkg//@/_}_$ver"

    rules+=("{
      \"_id\": \"\",
      \"package\": \"$pkg\",
      \"type\": \"nodejs\",
      \"minVersionInclusive\": \"$ver\",
      \"name\": \"$name\",
      \"maxVersionInclusive\": \"$ver\",
      \"md5\": \"\"
    }")
  done
done < "$input"

# Join array items with commas
json=$(printf "%s,\n" "${rules[@]}" | sed '$ s/,$//')
echo "{ \"rules\": [ $json ] }" | jq '.' > "$output"