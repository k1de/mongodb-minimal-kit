# mongodb-minimal-kit

Minimal MongoDB kit: isolated projects, dedicated users, secure setup.

## Project Structure

```
mongodb-minimal-kit/
├── create-project.sh    # Project creation script
├── docker-compose.yml   # MongoDB container
├── .env.template        # Configuration template
├── .env                 # Your configuration (don't commit)
├── data/                # MongoDB data (auto-created)
└── *.env                # Project credentials (don't commit)
```

## Quick Start

**Setup:**

```bash
cp .env.template .env
# Edit .env - change ROOT_PASSWORD
```

**Run MongoDB:**

```bash
docker-compose up -d
```

**Create Project:**

```bash
chmod +x create-project.sh
./create-project.sh myapp
```

Creates:

-   Database: `myapp_db`
-   Users: `myapp_reader` (read-only), `myapp_writer` (read-write)
-   File: `myapp.env` with connection strings

**Use in Code:**

```javascript
// Run with: node --env-file=myapp.env script.js
import { MongoClient } from 'mongodb'

const client = new MongoClient(process.env.WRITER_URI)
```

## Commands

**MongoDB:**

-   **Status:** `docker-compose ps`
-   **Logs:** `docker-compose logs -f`
-   **Stop:** `docker-compose stop`
-   **Remove (keeps data):** `docker-compose down`
-   **Remove everything:** `docker-compose down -v && rm -rf data/`

**Projects:**

-   **Create:** `./create-project.sh PROJECT_NAME`
-   **Recreate:** `./create-project.sh PROJECT_NAME --force`

## Security

-   Each project has isolated database
-   Users can only access their own database
-   Root account only for administration

## License

ISC © tish
