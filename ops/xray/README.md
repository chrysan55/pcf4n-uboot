# Builder Xray client

The Tencent Cloud builder cannot reliably reach GitHub directly. It runs an
Xray client with the same outbound configuration as the developer Mac.

Security constraints:

- the actual `config.json` contains credentials and is never committed;
- SOCKS (`127.0.0.1:10808`) and HTTP (`127.0.0.1:10809`) listen on loopback
  only;
- the service runs as `nobody` and cannot write system files;
- the Xray archive checksum is verified before installation;
- Git's system proxy points to the loopback HTTP inbound;
- build containers use host networking, so loopback remains reachable without
  opening a proxy port on the public interface.

Installed paths follow the upstream Xray installer convention:

```text
/usr/local/bin/xray
/usr/local/etc/xray/config.json
/usr/local/share/xray/geoip.dat
/usr/local/share/xray/geosite.dat
/etc/systemd/system/xray.service
```

Verification commands:

```bash
systemctl status xray
ss -lntp | grep -E '127.0.0.1:1080[89]'
curl --proxy http://127.0.0.1:10809 https://github.com/
git ls-remote https://github.com/altera-fpga/u-boot-socfpga.git \
  refs/tags/QPDS26.1_REL_GSRD_PR
```

To rotate credentials, securely copy the validated local configuration to
`/usr/local/etc/xray/config.json`, keep it `0640 root:nogroup`, run
`xray run -test -config ...`, and only then restart the service.
