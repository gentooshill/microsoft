# ::microsoft

Personal Gentoo overlay.

## Installation
```bash
sudo tee /etc/portage/repos.conf/microsoft.conf << 'CONF'
[microsoft]
location = /var/db/repos/microsoft
sync-type = git
sync-uri = https://github.com/gentooshill/microsoft.git
auto-sync = yes
CONF
```

sudo emerge --sync microsoft
