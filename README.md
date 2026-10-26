# mpardalos' homelab

## Deploy

``` sh
nix develop --command deploy
```

## Startpage

Declare each service in its Nix module:

```nix
my.services.example = rec {
  name = "Example";
  url = "example.home.mpardalos.com";
  port = 8080;
  order = 90;
  icon.url = "${url}/favicon.ico";
};
```

The common module writes these declarations to `/etc/service-inventory.json`.
The startpage reads that inventory directly. The attribute name is the tile ID;
`serviceName` defaults to `example.service`, `name` to the ID, and `order` to 100.
Set `serviceName` explicitly when the systemd unit differs from the ID. Lower
orders appear first, with ties ordered by ID.

Hostnames without a scheme are rendered as HTTPS links. Explicit HTTP/HTTPS URLs
and local icon paths are also supported. Icons accept `icon.url` or trusted
`icon.html` markup, such as an inline SVG.

The startpage module derives restart permissions from the same inventory.
PHP resolves `systemctl`, `journalctl`, `timeout`, and `sudo` through PATH; the
PHP-FPM pool sets PATH to the NixOS wrapper and system-bin directories. The
inventory contains no tool paths. Apply the NixOS configuration to update the
inventory, permissions, and PHP environment.

For local development or tests, set `HOMELAB_CONFIG` to another inventory JSON
file with the same format. Without an override, PHP reads
`/etc/service-inventory.json`. Tests put fake commands on PATH, so they never
restart real services or reboot the host.
