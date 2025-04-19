
# eja - Micro Web Server and Lua Toolkit

`eja` is a versatile command-line tool primarily designed as a lightweight web server for static and dynamic content. It also functions as a text scanner utility (similar to `awk` but using Lua patterns) and a standalone Lua 5.2 interpreter with extended functionalities baked in.

Originally available for Debian/Linux, `eja` has now been updated and ported to other Unix-like operating systems, including macOS (Darwin). It achieves its functionality through a combination of C code for core system interactions (such as process management, sockets, and file system operations) and a rich set of embedded Lua libraries for higher-level tasks.

## Features

*   **Micro Web Server:**
    *   Serves static files.
    *   Handles dynamic content through `.lua` or pre-compiled `.eja` scripts.
    *   Configurable host, port, web root path, and buffer size.
    *   Optional directory listing.
    *   Background daemon mode (`--web-start`, `--web-stop`).
    *   Simple time-based hash authentication mechanism (`ejaWebAuth`).
    *   User management helper (`--web-user`).
*   **Text Scanner:**
    *   Processes text streams (stdin or file) line by line or based on custom record separators.
    *   Uses Lua patterns for field separation (default: `%S+`).
    *   Executes Lua scripts for each record, providing the full row (`R`) and matched fields (`F`).
*   **Lua Interpreter:**
    *   Runs Lua 5.2 scripts.
    *   Includes an interactive shell (`--shell`).
    *   Can execute `.eja` portable bytecode files.
    *   Exports Lua scripts to `.eja` bytecode (`--export`).
*   **Extended Functionality (via C bindings & embedded Lua libs):**
    *   **System Interaction:** Process creation, killing, sleeping (fork, kill, sleep), PID retrieval, cleaning up child processes, file stats (stat), directory listing and creation.
    *   **Networking:** Low-level TCP/UDP socket operations (create, bind, connect, listen, accept, read, write, options), DNS lookups (getaddrinfo). Includes helper functions for HTTP GET/POST (ejaWebGet, ejaJsonPost).
    *   **Simple Database:** File-based key-value store (`ejaDb*` functions).
    *   **Data Handling:** JSON encoding/decoding, Base64 encoding/decoding, struct packing/unpacking.
    *   **Encryption & Hashing:** AES encryption/decryption, SHA1, SHA256.
    *   **MariaDB/MySQL Client:** Embedded client for database interactions.
    *   **Utilities:** MIME type detection, TAR file extraction, logging framework, table manipulation helpers, string formatting.
    *   **Library Management:** Simple update/install/remove mechanism for `.eja` libraries (`--update`, `--install`, `--remove`).
    *   **System Setup:** Helper command (`--setup`) to create default directories and configuration files (including a basic systemd service file).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/eja/eja.git
    cd eja
    ```
2.  **Compile:**
    ```bash
    make
    ```
    For a statically linked binary (if supported by your toolchain):
    ```bash
    make static
    ```
3.  **Install (optional):**
    By default, this installs to `/usr/local`. You might need `sudo`.
    ```bash
    sudo make install
    ```
    This will install the `eja` binary to `/usr/local/bin` and the man page to `/usr/local/share/man/man1`.

## Usage

The basic syntax is:

```bash
eja [SCRIPT] [OPTION]...
```

For a full list of options, see the man page:

```bash
man eja
```
Or display help in the terminal:
```bash
eja --help       # Basic help
eja --help full  # Full help including library options
```

### General Examples

*   **Run a Lua script:**
    ```bash
    eja myscript.lua
    ```
*   **Run an eja bytecode script:**
    ```bash
    eja mybytecode.eja
    ```
*   **Use as a text scanner:**
   
    print second word of each line:
    ```bash
    cat somefile.txt | eja --scan 'print(F[2])'
    ```
    
    print lines matching "ERROR":
    ```bash
    cat somefile.txt | eja --scan "/ERROR/"
    ```
*   **Start the interactive Lua shell:**
    ```bash
    eja --shell
    ```
*   **Export a Lua script to bytecode:**
    ```bash
    eja --export myscript.lua --export-name mybytecode
    # Creates mybytecode.eja
    ```
*   **Update eja or an eja library:**
    ```bash
    eja --update             # Updates eja itself
    eja --update mylibrary   # Updates mylibrary.eja from update.eja.it or GitHub
    ```

### Web Server Functionality

`eja` makes it simple to run a local web server for various purposes.

**1. Directory Listing:**

To quickly share or browse files in a directory via HTTP, enable directory listing:

```bash
# Navigate to the directory you want to serve
cd ~/my_shared_files

# Start eja, enabling directory listing on the default port (35248)
eja --web
```

Now, open your web browser and go to `http://localhost:35248`. You will see a list of files and subdirectories within `~/my_shared_files`. Clicking a file will download it, and clicking a directory will navigate into it.

**2. Static HTML/Website Testing:**

If you are developing a simple website (HTML, CSS, JavaScript, images), you can use `eja` as a local test server:

```bash
# Assume your website files are in ~/projects/my_website
# with index.html at the root
cd ~/projects/my_website

# Start eja in the project directory
eja --web --web-port 8000 # Use port 8000 instead of the default
```

*   Access the site at `http://localhost:8000`.
*   `eja` will automatically serve `index.html` if it exists in the current directory (`~/projects/my_website`).
*   It will also serve other files like `style.css` if your HTML references them with relative paths (e.g., `<link rel="stylesheet" href="style.css">`).

**3. Dynamic Content (Simple URL Sum):**

`eja` can execute Lua scripts (`.lua` or compiled `.eja`) to generate dynamic responses. The script receives a `web` object containing request details and can modify it to set the response.

*   **Create the script (`sum.lua`):** Save the following code in a file named `sum.lua`:

    ```lua
    -- sum.lua
    -- The 'web' object is implicitly passed as the first argument
    web = ... 

    -- Get query parameters 'a' and 'b' from the URL
    -- web.opt contains decoded query parameters
    local a = tonumber(web.opt.a) or 0
    local b = tonumber(web.opt.b) or 0
    local result = a + b

    -- Set the response content type and data
    web.headerOut['Content-Type'] = 'text/plain'
    web.data = string.format("The sum of %s and %s is: %s", a, b, result)

    -- No need to explicitly return the web object, modifying it is sufficient.
    ```

*   **Run the server:** Navigate to the directory containing `sum.lua` and start `eja`:

    ```bash
    cd /path/to/directory/containing/script
    eja --web
    ```

*   **Access the dynamic endpoint:** Open your browser or use `curl`:

    ```bash
    curl "http://localhost:35248/sum.lua?a=15&b=27" 
    ```

    This will output:
    ```
    The sum of 15 and 27 is: 42
    ```

    You can change the values of `a` and `b` in the URL to get different results. If parameters are missing, they default to 0.

**4. Daemon Control:**

*   **Start the web server as a background daemon (using defaults or config):**
    ```bash
    eja --web-start
    ```
*   **Stop the web server running on the default port (35248):**
    ```bash
    eja --web-stop
    ```
*   **Stop the web server running on port 8080:**
    ```bash
    eja --web-stop 8080
    ```

## Configuration

*   **Compile-time Paths:** Default paths for libraries, configuration, logs, etc., can be set during compilation via CFLAGS in the `Makefile` (e.g., `make CFLAGS="-DEJA_PATH_ETC=/etc/eja" install`).
*   **Runtime Configuration:** The `--init` option loads `/etc/eja/eja.init` (by default). This Lua file can set `eja.opt` values to configure behavior, commonly used for the daemon started via `--web-start` or a system service.
*   **System Setup:** The `eja --setup` command helps create default directories (`/var/eja/web`, `/var/lock`, `/tmp`, etc.) and a basic `/etc/eja/eja.init` file, along with a sample systemd service unit.
