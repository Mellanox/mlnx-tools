#!/usr/bin/env python3

import argparse
import os
import json
import subprocess
import textwrap

CONFIG_FILE = "/etc/mellanox/mlnx-hugepages.conf"

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_config(config):
    if not os.path.isdir(os.path.dirname(CONFIG_FILE)):
        raise FileNotFoundError(f"Directory {os.path.dirname(CONFIG_FILE)} does not exist")

    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)

"""Get a list of valid hugepage sizes supported by the system."""
def get_valid_hugepage_sizes():
    hugepage_dir = "/sys/kernel/mm/hugepages"
    return sorted([int(d.split('-')[1][:-2]) for d in os.listdir(hugepage_dir) if d.startswith("hugepages-")])

def configure_hugepages(config):
    valid_sizes = get_valid_hugepage_sizes()
    current_allocations = {}

    for size in valid_sizes:
        try:
            cmd = f"cat /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
            result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
            current_allocations[size] = int(result.stdout.strip())

            if current_allocations[size] > 0:
                reset_cmd = f"echo 0 | sudo tee /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
                subprocess.run(reset_cmd, shell=True, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            print(f"Error accessing hugepages of size {size}kB: {e.stderr.strip()}")
            return

    size_totals = {}
    for app, app_config in config.items():
        size = app_config['size']
        num = app_config['num']
        size_totals[size] = size_totals.get(size, 0) + num

    for size, total in size_totals.items():
        cmd = f"echo {total} | sudo tee /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
        try:
            subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
            print(f"Successfully configured {total} hugepages of size {size}kB")
        except subprocess.CalledProcessError as e:
            print(f"Error configuring hugepages of size {size}kB: {e.stderr.strip()}")

def configure_hugepages(config):
    valid_sizes = get_valid_hugepage_sizes()
    current_allocations = {}

    # Reset current hugepage allocations
    for size in valid_sizes:
        try:
            cmd = f"cat /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
            result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
            current_allocations[size] = int(result.stdout.strip())

            if current_allocations[size] > 0:
                reset_cmd = f"echo 0 | sudo tee /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
                subprocess.run(reset_cmd, shell=True, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            print(f"Error accessing hugepages of size {size}kB: {e.stderr.strip()}")
            return

    size_totals = {}
    successfully_configured_apps = []

    for app, app_config in config.items():
        size = app_config['size']
        num = app_config['num']
        size_totals[size] = size_totals.get(size, 0) + num

    for size, total in size_totals.items():
        cmd = f"echo {total} | sudo tee /sys/kernel/mm/hugepages/hugepages-{size}kB/nr_hugepages"
        try:
            subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
            print(f"Successfully configured {total} hugepages of size {size}kB")

            for app, app_config in config.items():
                if app_config['size'] == size:
                    app_config['is_active'] = "active"
                    successfully_configured_apps.append(app)

        except subprocess.CalledProcessError as e:
            print(f"Error configuring hugepages of size {size}kB: {e.stderr.strip()}")

    # Save the updated configuration back to the database
    if successfully_configured_apps:
        save_config(config)

def reload_config(args):
    config = load_config()
    configure_hugepages(config)

def get_available_memory_kb():
    try:
        result = subprocess.run(["grep", "MemAvailable", "/proc/meminfo"], capture_output=True, text=True, check=True)
        mem_available = int(result.stdout.split()[1])
        return mem_available
    except subprocess.CalledProcessError:
        print("Error: Unable to retrieve available memory information.")
        return None

def add_app_config(args):
    # Validate the hugepage size
    valid_sizes = get_valid_hugepage_sizes()

    if args.size not in valid_sizes:
        print(f"Error: The hugepage size {args.size}kB is not supported by your system.")
        print(f"Supported sizes are: {', '.join(map(str, valid_sizes))}")
        return

    # Check if the app already exists in the configuration
    config = load_config()

    if args.app in config and not args.force:
        print(f"Configuration for {args.app} already exists.")
        update = input("Do you want to update it? (y/n): ").lower().strip()
        if update != 'y':
            print("Configuration not updated.")
            return

    # Check if there is enough available memory
    new_config_memory_kb = args.size * args.num  # Memory required for the new configuration in kB

    total_allocated_memory_kb = sum(
        app_config['size'] * app_config['num'] for app_config in config.values()
    )

    available_memory_kb = get_available_memory_kb()

    if total_allocated_memory_kb + new_config_memory_kb > available_memory_kb:
        print(f"Error: Not enough available memory for this configuration.")
        print(f"Requested: {new_config_memory_kb / 1024:.2f} MB, "
              f"Available: {available_memory_kb / 1024:.2f} MB, "
              f"Currently Allocated: {total_allocated_memory_kb / 1024:.2f} MB")
        return

    # Add or update the configuration
    action = 'updated' if args.app in config else 'added'
    config[args.app] = {
                        "size": args.size,
                        "num": args.num,
                        "is_active": "inactive"
                       }
    save_config(config)
    print(f"Configuration for {args.app} {action}.")

def remove_app_config(args):
    config = load_config()
    if args.app in config:
        del config[args.app]
        save_config(config)
        print(f"Configuration for {args.app} deleted.")
    else:
        print(f"No configuration found for {args.app}.")

def show_config(args):
    config = load_config()
    has_inactive_config = False

    if config:
        print("\nCurrent Hugepages Configuration:")
        print(f"{'Application':<20}{'Page Size (kB)':<20}{'Number of Pages':<20}{'Allocated (GB)':<20}{'Is Active':<20}")
        print("=" * 90)

        total_size_kb = 0

        for app, app_config in config.items():
            page_size_kb = app_config['size']
            number_of_pages = app_config['num']
            app_allocated_kb = page_size_kb * number_of_pages
            app_allocated_gb = app_allocated_kb / (1024 * 1024)
            total_size_kb += app_allocated_kb
            is_active = app_config.get('is_active', 'unknown')

            if is_active.lower() == 'inactive':
                has_inactive_config = True

            # Print each application's configuration as a row in the table
            print(f"{app:<20}{page_size_kb:<20}{number_of_pages:<20}{app_allocated_gb:<20.2f}{is_active:<20}")

        # Convert total size from KB to GB
        total_size_gb = total_size_kb / (1024 * 1024)
        print("=" * 90)
        print(f"{'Total':<20}{'':<20}{'':<20}{total_size_gb:<20.2f}")

        if has_inactive_config:
            print("\nNote: The configurations marked as 'inactive' are saved but not currently in use. To")
            print("      enable these configurations and allocate the required hugepages, execute the")
            print("      'reload' command. This will bring your system in line with the stored")
            print("      configurations.")
    else:
        print("No configuration found. Try adding one.")

def create_parser():
    parser = argparse.ArgumentParser(
        prog='mlnx-hugepages',
        description="Manage hugepages configuration for applications.",
        usage='mlnx-hugepages [-h] {config,reload,remove,show}',
        add_help=True
    )

    subparsers = parser.add_subparsers(
        dest="command",
        metavar="",
        title="Available commands",
        help=""
    )

    # Config subparser
    config_parser = subparsers.add_parser(
        "config",
        usage='mlnx-hugepages config [--force] <app> <size> <num>',
        help="Add/update app configuration",
        description=textwrap.fill(
                "Adds a configuration for a specific application to the database. "
                "This command only adds/updates the stored configuration and does not apply changes. "
                "Use the 'reload' command to actually allocate hugepages based on the database configurations.",
                width=90
            ),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    config_parser.add_argument("app", help="Name of the application. (Could be anything)")
    config_parser.add_argument("size", type=int, help=f"Hugepage size in kB. Available sizes: { get_valid_hugepage_sizes()}")
    config_parser.add_argument("num", type=int, help="Number of hugepages to allocate.")
    config_parser.add_argument("--force", action="store_true", help="Force updating the configuration without prompting.")

    # Reload subparser
    reload_parser = subparsers.add_parser(
        "reload",
        usage='mlnx-hugepages reload',
        help="Reload the hugepages configuration",
        description=textwrap.fill(
                "Reload the hugepages configuration for all applications based on the current settings in the database. "
                "This will bring your system in line with the stored configurations. ",
                width=90
            ),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    # Remove subparser
    remove_parser = subparsers.add_parser(
        "remove",
        usage='mlnx-hugepages remove <app>',
        help="Remove app configuration",
        description=(
            "Remove a configuration from the database."
        ),
    )
    remove_parser.add_argument("app", help="An application to remove from the configuration")

    # Show subparser
    show_parser = subparsers.add_parser(
        "show",
        usage='mlnx-hugepages show',
        help="Display current configuration",
        description=(
            "Dump the current hugepages configuration for all applications in the database."
        ),
    )

    return parser

def execute_command(args, parser):
    command_functions = {
        "config": add_app_config,
        "reload": reload_config,
        "remove": remove_app_config,
        "show": show_config
    }

    if args.command in command_functions:
        command_functions[args.command](args)
    else:
        parser.print_help()

def main():
    parser = create_parser()
    args = parser.parse_args()
    execute_command(args, parser)

if __name__ == "__main__":
    main()
