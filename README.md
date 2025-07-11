# MediaWikiInstance

This repository contains a Docker Compose configuration for running a MediaWiki
instance with a MySQL database, along with the [Loftia] skin.

## Prerequisites

 - Docker and Docker Compose, or compatible such as Podman and Podman Compose.

## How to Use This Repository

 1. Clone this repository to your local machine:
    ```bash
    git clone
     ```
 2. Navigate to the cloned directory:
    ```bash
    cd MediaWikiInstance
    ```
 3. Start the MediaWiki and MySQL containers using Docker Compose. The `-d` flag
    starts the containers in a daemonized mode.
    ```bash
     docker-compose up -d
     ```
 4. Open your web browser and navigate to `http://localhost:8080` to access the
    MediaWiki setup page.
 5. Follow the on-screen instructions to complete the MediaWiki installation.
 6. After completing the installation, you can log in to your MediaWiki instance
    and start creating and managing your wiki content.
 7. To stop the containers, run:
 
    ```bash
     docker-compose down
     ```

[0]: https://github.com/PrestonHager/LoftiaMediaWikiSkin

