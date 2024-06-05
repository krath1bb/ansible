# MagicMirror²
MagicMirror² install from source on Debian Bullseye.

## Requirements
No additional requirements.

## Role Variables
Settings have been throughly documented for usage.
[defaults/main.yml](https://github.com/r-pufky/ansible_mirror/blob/main/defaults/main.yml).

## Dependencies
[community.general.ini_file](https://docs.ansible.com/ansible/latest/collections/community/general/ini_file_module.html)

## Example Playbook
The following example will get an instance quickly up and running. All module
and display configuration is set within the ansible role. Read through defaults
before using. Assumes you are already managing the debian system.

host_vars/mirror.example.com/vars/mirror.yml
``` yaml
# Create 'mirror' user if not detected? See: vars/main.yml.
mirror_create_user: true
# Orientation of the mirror display. Applied to the first connected display.
mirror_orientation: 'normal'
```

site.yml
``` yaml
- name:   'mirror'
  hosts:  'mirror.example.com'
  become: true
  roles:
    - {{ debian_role }}
    - 'r_pufky.mirror'
```

## Add Custom Modules
These are automatically managed with the role. Applied in the order listed in
configuration and automatically converted to JSON. Read through defaults for
detailed instructions.

Module requiring `npm install`:
``` yaml
mirror_modules:
  ...
  - source: 'https://github.com/nigel-daniels/MMM-AirNow'
    install: 'npm install'
    setting:
      module: 'MMM-AirNow'
      position: 'top_left'
      config:
        api_key: 'your-api-key'
        zip_code: '20500'
  ...
```

Module requiring advanced install:
``` yaml
mirror_modules:
  ...
  - source: 'https://github.com/Snille/MMM-homeassistant-sensors'
    install: 'npm init && npm install request'
    setting:
      module: 'MMM-homeassistant-sensors'
      position: 'top_left'
      config:
        host: 'IP TO HOME ASSISTANT'
        port: 8123
        https: false
        token: 'YOUR OWN'
        values:
          - {sensor: 'sensor.vind_temperature'}
          - {sensor: 'sensor.vind_humidity'}
```

## Issues
Create a bug and provide as much information as possible.
Associate pull requests with a submitted bug.

## License
[AGPL-3.0 License](https://github.com/r-pufky/ansible_mirror/blob/main/LICENSE)

## Author Information
https://keybase.io/rpufky
