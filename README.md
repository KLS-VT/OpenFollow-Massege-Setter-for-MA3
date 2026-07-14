# OpenFollow Message Setter for grandMA3

A grandMA3 Lua plugin for creating OpenFollow OSC message commands directly inside Cue Parts.

The plugin opens a simple input dialog where you can enter Sequence, Cue, Marker ID, Message, Info, and Dismiss-Time.  
It then creates or updates a Cue Part and writes the correct `SendOSC` command into the Cue Command field.

## Features

- Creates an OpenFollow OSC message command
- Stores the command inside a Cue Part
- Automatically creates the required Cue Part
- Labels the Part with the OpenFollow Marker ID
- Uses Marker ID to calculate the Part number
- Includes a Settings menu for OSC IP and Port
- Creates or updates an OSC Data Line named `OpenFollow`
- Checks OSC output settings
- Default OSC port: `8765`

## Cue Command Format

The plugin creates Cue Commands in this format:

```text
SendOSC "OpenFollow" "/message,ssif,<Message>,<Info>,<Marker ID>,<Dismiss-Time>"
```

Example:

```text
SendOSC "OpenFollow" "/message,ssif,Cue 12,Lead Vocal,0,5.0"
```

## Input Fields

The main popup contains these fields:

| Field | Description |
|---|---|
| Sequence | Target sequence number |
| Cue | Target cue number |
| Marker ID | OpenFollow marker ID. Numbers only. Default is `0` |
| Message | Message text sent to OpenFollow |
| Info | Additional info text sent to OpenFollow |
| Dismiss-Time | Time in seconds until the message is dismissed |

## Part Number Logic

The plugin stores the command in a Cue Part based on the Marker ID:

```text
Part Number = 9000 + Marker ID
```

Examples:

| Marker ID | Cue Part |
|---:|---:|
| 0 | 9000 |
| 1 | 9001 |
| 10 | 9010 |
| 100 | 9100 |

## OSC Settings

The Settings menu allows you to enter:

| Field | Default |
|---|---|
| IP Address | `127.0.0.1` |
| Port | `8765` |

When saved, the plugin creates or updates an OSC Data Line named:

```text
OpenFollow
```

This OSC Data Line is used by the generated Cue Command:

```text
SendOSC "OpenFollow" ...
```

## Installation

This plugin is provided as two files:

- `OpenFollow Message Setter.xml`
- `OpenFollow Message Setter.lua`

### Install on grandMA3

1. Copy both files to your grandMA3 plugin import folder.
2. Import the XML file into the grandMA3 Plugin Pool.
3. Make sure the Lua file is located next to the XML file or in the correct grandMA3 plugin folder.
4. Run the plugin from the Plugin Pool.
5. Open **Settings** once and enter the OpenFollow target IP address and port.
6. Use the main dialog to create OpenFollow Cue Commands.

### Required Files

The XML file contains the grandMA3 plugin object/import structure.  
The Lua file contains the actual plugin code.

Both files are required for installation.

## Usage

1. Run the plugin.
2. Enter the target Sequence and Cue.
3. Enter the Marker ID.
4. Enter the Message, Info, and Dismiss-Time.
5. Press `Save`.

The plugin will:

1. Create or merge the required Cue Part.
2. Write the OpenFollow `SendOSC` command into the Cue Command field.
3. Label the Part with the Marker ID.

## Example

Input:

```text
Sequence: 1
Cue: 12
Marker ID: 0
Message: Cue 12
Info: Lead Vocal
Dismiss-Time: 5.0
```

Generated Cue Command:

```text
SendOSC "OpenFollow" "/message,ssif,Cue 12,Lead Vocal,0,5.0"
```

Target Part:

```text
Sequence 1 Cue 12 Part 9000
```

Part Label:

```text
OpenFollow ID 0
```

## Notes

- Marker ID only accepts numbers.
- Cue accepts normal cue numbers such as `1`, `12`, or `1.5`.
- The plugin is designed for grandMA3 Lua.
- The OSC Data Line must be named `OpenFollow`, because the generated command references this name.
- The plugin currently uses `MessageBox()` for the user interface.
- The plugin installation requires both the XML file and the Lua file.

## License

MIT License

## Author

Kevin Klaes
