# PCE DAO Protocol

## Docker Setup

### Prerequisites

- Install Docker:

  1. Visit https://www.docker.com/get-started/
  2. Download Docker Desktop for your operating system (Windows/Mac/Linux)
  3. Run the installer and follow the setup wizard
  4. Start Docker Desktop after installation

- Install Docker Compose:
  - For Windows/Mac: Docker Compose is included with Docker Desktop
  - For Linux:
    1. Run: `sudo apt-get update`
    2. Install with: `sudo apt-get install docker-compose`
    3. Verify with: `docker-compose --version`

### Getting Started

1. Clone the repository:
   https://github.com/peacecoin-protocol/dao

2. Navigate to the repository directory:

   ```bash
   cd dao
   ```

3. Run the following command to start the Docker containers:
   ```bash
   docker compose up
   ```
