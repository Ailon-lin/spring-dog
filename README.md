# spring-dog firmware

RIG-Puppy 的公开固件 Release，供 `spring-dog-cli` 一键烧录使用。

- catalog: https://raw.githubusercontent.com/Ailon-lin/spring-dog/main/catalog.json
- 版本包：本仓库的 GitHub Releases（扁平资产）

```bash
node scripts/spring-dog.mjs init \
  --catalog https://raw.githubusercontent.com/Ailon-lin/spring-dog/main/catalog.json \
  --board puppy

node scripts/spring-dog.mjs flash --version latest --mode full
```
