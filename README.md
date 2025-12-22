# mongodb-minimal-kit

Minimal MongoDB kit: isolated projects, dedicated users, secure setup.

## Quick Start (local, no TLS)

```bash
cp .env.template .env
# Edit .env - change ROOT_PASSWORD

docker-compose up -d
./create-project.sh myapp
```

Creates `myapp_db` with users `myapp_reader` / `myapp_writer` and saves credentials to `myapp.env`, `myapp.json`.

## TLS (for production)

```bash
# Edit .env:
# TLS_ENABLED=true
# CERT_HOSTNAME=your-server.com
# CERT_IP=203.0.113.50

./generate-certs.sh
docker-compose up -d
```

Credentials include `caBase64` for client TLS configuration.

## Commands

| Action           | Command                                  |
| ---------------- | ---------------------------------------- |
| Start            | `docker-compose up -d`                   |
| Stop             | `docker-compose down`                    |
| Logs             | `docker-compose logs -f`                 |
| Create project   | `./create-project.sh NAME`               |
| Recreate project | `./create-project.sh NAME --force`       |
| Reset all        | `docker-compose down -v && rm -rf data/` |

## License

ISC © tish
