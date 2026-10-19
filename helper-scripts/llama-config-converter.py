#!/usr/bin/env python3

import configparser
import sys
import argparse
import os

def convert_to_swap_yaml(ini_file, yaml_file, server_bins):
    # Initialize parser and prevent it from auto-lowercasing keys
    config = configparser.ConfigParser()
    config.optionxform = str

    if not os.path.exists(ini_file):
        print(f"Error: Could not find {ini_file}")
        sys.exit(1)

    config.read(ini_file)

    yaml_lines = [
        "# Generated from models.ini for llama-swap",
        "models:"
    ]

    # 1. Extract global fallback settings from [*] if it exists
    # configparser strips the brackets, so we look for "*" instead of "[*]"
    global_settings = {}
    if "*" in config.sections():
        global_settings = dict(config.items("*"))

    model_count = 0

    for section in config.sections():
        # 2. Skip turning the global section itself into a llama-swap model endpoint
        if section == "*":
            continue

        model_count += 1
        yaml_lines.append(f"  {section}:")

        # Initialize command with the binary and mandatory llama-swap PORT macro
        if section in ['ternary-bonsai-2-27b','gemma-4-12b']:
            cmd_parts = [server_bins[0], "--port ${PORT}"]
        else:
            cmd_parts = [server_bins[1], "--port ${PORT}"]
        # 3. Merge global settings with section-specific settings.
        # Specific model settings overwrite global ones if there's a key collision.
        section_settings = dict(config.items(section))
        merged_settings = {**global_settings, **section_settings}

        for key, val in merged_settings.items():
            # Clean up potential existing quotes from the INI
            val = val.strip("\"'")
            val_lower = val.lower()

            # Handle boolean flags (e.g., flash_attn = true -> --flash_attn)
            if val_lower in ["true", "on", "yes"] and key not in ['flash-attn']:
                cmd_parts.append(f"--{key}")
            # Drop flags explicitly set to false
            elif val_lower in ["false", "off", "no"]:
                continue
            # Handle standard key-value arguments
            else:
                # Wrap values with spaces in quotes
                if " " in val:
                    cmd_parts.append(f'--{key} "{val}"')
                else:
                    cmd_parts.append(f"--{key} {val}")

        cmd_str = " ".join(cmd_parts)
        yaml_lines.append(f"    cmd: '{cmd_str}'")
        # Basic TTL: Unloads the model after 5 minutes of inactivity
        yaml_lines.append(f"    ttl: 300\n")

    with open(yaml_file, 'w') as f:
        f.write("\n".join(yaml_lines))

    print(f"Successfully translated {model_count} models into {yaml_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert llama.cpp models.ini to llama-swap config.yaml")
    parser.add_argument("-i", "--input", default="./../machine-2/llm-models/config/models.ini", help="Path to input models.ini")
    parser.add_argument("-o", "--output", default="./../machine-2/llm-models/config/config.yaml", help="Path to output YAML file")
    parser.add_argument("-b", "--binary", default=["/app/llama-sycl-torchit1/bin/llama-server","/app/llama-sycl/llama-server"], help="Path to the llama-server executable to use in the cmd")

    args = parser.parse_args()
    convert_to_swap_yaml(args.input, args.output, args.binary)
