# mpardalos' homelab

## Deploy

``` sh
nix develop --command deploy
```

## Startpage

Declare a button alongside its service in the service's Nix module:

```nix
my-services.service-buttons.example = {
  name = "Example";
  order = 90;
  icon.url = "https://example.home.mpardalos.com/favicon.ico";
};
```

The attribute name is the button ID. `serviceName` defaults to `example.service`,
and `url` defaults to that service's reverse-proxy URL. Set either explicitly when
they differ. `name` defaults to the ID; `order` defaults to 100, with ties ordered
by ID. Icons accept `icon.url` (a local path or HTTPS URL) or trusted `icon.html`
markup, such as an inline SVG.

The startpage module generates `/etc/homelab-startpage.json` and the corresponding
sudo rules for restarting exactly those units. PHP reads the generated file;
adding a service requires no PHP or JavaScript changes. Apply the NixOS
configuration to update both the inventory and permissions.

For local development, generate a preview inventory from the same Nix declarations:

```sh
nix build '.#nixosConfigurations.nixie.config.environment.etc."homelab-startpage.json".source' --out-link /tmp/homelab-startpage-config
cp --remove-destination /tmp/homelab-startpage-config startpage/config.json
```

`startpage/config.json` is generated and ignored by Git. PHP prefers
`HOMELAB_CONFIG`, then the deployed `/etc/homelab-startpage.json`, and uses the local
copy when neither is available. The generated inventory contains no secrets.
