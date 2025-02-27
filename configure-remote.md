# Remote machine configuration

It is possible to configure other machines (let’s call them **remote**) so that they can be managed by Portainer running on **server**.
To do so, follow the steps below based on the need for a secure or insecure communication with the server.

---

## Insecure

### **1. Enable Remote Docker API on `remote`**
Portainer needs to communicate with Docker on `remote`, so we need to expose Docker’s API.

#### **(a) Edit the Docker service**
Run the following on `remote`:

```sh
sudo mkdir -p /etc/systemd/system/docker.service.d
```
Create a new file for configuration:
```sh
sudo nano /etc/systemd/system/docker.service.d/override.conf
```
Add the following content:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375
```
- `-H fd://` → Keeps the default local socket.
- `-H tcp://0.0.0.0:2375` → Opens the API on port `2375` (unsecured).

#### **(b) Reload and restart Docker**
```sh
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### **(c) Verify API exposure**
Run:
```sh
curl http://localhost:2375/info
```
If you see a JSON response with Docker info, the API is accessible.

---

### **2. Allow Connections from `server` Only (Optional but Recommended)**
By default, the API is open to any machine on the network, which is insecure. 
If you want to restrict it so only `server` can connect, you can use a firewall.

Run this on `remote`:
```sh
sudo ufw allow from <server-ip> to any port 2375
```
Replace `<server-ip>` with the actual IP of `server`.

---

### **3. Add `remote` to Portainer**
Now go to **Portainer** running on `server`:
1. Navigate to **Environments**.
2. Click **Add Environment**.
3. Choose **Docker** → **Remote**.
4. Set the **Environment Name** (e.g., `remote-docker`).
5. In the **Environment URL**, enter:
   ```
   tcp://<remote-ip>:2375
   ```
   Replace `<remote-ip>` with the actual IP of `remote`.
6. Click **Connect** and save.

If the connection is successful, `remote` will now appear in the Portainer dashboard!

---

## Secure - TLS

Since exposing Docker's API over an open TCP port (`2375`) is insecure, we can configure **TLS authentication** to ensure only `server` (where Portainer runs) can connect securely.  

---

### **Step 1: Install OpenSSL on Both Machines**
Run the following on **both `server` and `remote`** to ensure OpenSSL is installed:  
```sh
sudo apt update && sudo apt install -y openssl
```

---

### **Step 2: Create TLS Certificates**
You'll generate certificates on **`remote`**, then copy some to **`server`**.

#### **(a) Generate a Certificate Authority (CA) on `remote`**
```sh
mkdir -p ~/docker-certs && cd ~/docker-certs
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -subj "/CN=CA" -out ca.pem
```
This creates:
- `ca-key.pem` → The private key for the CA.
- `ca.pem` → The CA certificate.

#### **(b) Create the Server Certificate for `remote`**
```sh
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -subj "/CN=remote" -out server.csr
```
Then, create an **OpenSSL config file** (`extfile.cnf`) with:
```sh
echo "subjectAltName = IP:<remote-ip>" > extfile.cnf
```
Replace `<remote-ip>` with the actual IP of `remote`.

Now, sign the certificate:
```sh
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf
```
This creates:
- `server-key.pem` → The private key.
- `server-cert.pem` → The signed certificate.

#### **(c) Create the Client Certificate for `server`**
```sh
openssl genrsa -out client-key.pem 4096
openssl req -new -key client-key.pem -subj "/CN=client" -out client.csr
openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -extfile extfile.cnf
```
This creates:
- `client-key.pem` → The private key.
- `client-cert.pem` → The signed certificate.

---

### **Step 3: Configure Docker on `remote` to Use TLS**
Move the TLS files to Docker’s cert directory:
```sh
sudo mkdir -p /etc/docker/certs
sudo mv ~/docker-certs/{ca.pem,server-cert.pem,server-key.pem} /etc/docker/certs/
sudo chmod 600 /etc/docker/certs/server-key.pem
```

Edit the Docker service configuration:
```sh
sudo nano /etc/systemd/system/docker.service.d/override.conf
```
Replace with:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// \
    -H tcp://0.0.0.0:2376 \
    --tlsverify \
    --tlscacert=/etc/docker/certs/ca.pem \
    --tlscert=/etc/docker/certs/server-cert.pem \
    --tlskey=/etc/docker/certs/server-key.pem
```
- `-H tcp://0.0.0.0:2376` → Exposes API on port `2376` (secure TLS).
- `--tlsverify` → Enables TLS authentication.

Reload and restart Docker:
```sh
sudo systemctl daemon-reload
sudo systemctl restart docker
```

Verify it's listening on `2376`:
```sh
ss -lntp | grep 2376
```

---

### **Step 4: Configure `server` to Use TLS**
Copy these files **from `remote` to `server`**:  
- `ca.pem`
- `client-cert.pem`
- `client-key.pem`

On `server`, store them in a directory:
```sh
mkdir -p ~/docker-certs
scp remote:~/docker-certs/{ca.pem,client-cert.pem,client-key.pem} ~/docker-certs/
```

---

### **Step 5: Add `remote` to Portainer Using TLS**
1. Go to **Portainer → Environments**.  
2. Click **Add Environment**.  
3. Choose **Docker** → **Remote**.  
4. Set **Environment Name** (e.g., `remote-docker`).  
5. In **Environment URL**, enter:  
   ```
   tcp://<remote-ip>:2376
   ```
6. Enable **TLS** and **TLS Verification**.  
7. Upload the **CA, Client Certificate, and Client Key** from `~/docker-certs/`.  
8. Click **Connect** and save.

---

### **Step 6: Test the Connection**
If everything is correct, `remote` will now appear in Portainer as a secured Docker environment. 🎉  

Would you like to automate certificate renewal later?

## Common issues
On certain occasions, you may run into problems due to bad configuration or a malformed URL. 
Some things to consider are list below:

---

### **1. Check the URL Format in Portainer**  
Make sure you're using the correct format in the **Environment URL** field when adding `remote` in Portainer:

✅ **Correct format:**  
```
192.168.10.9:2376
```
or  
```
tcp://192.168.10.9:2376
```

❌ **Incorrect format (causes issues):**  
```
tcp:/192.168.10.9:2376` (note the single `/`)
```
Make sure **you are not missing the double slashes (`//`)** after `tcp:`.

---

### **2. Verify Docker API is Listening on `remote`**
Run this command on **remote** to check if Docker is actually listening on port `2376`:

```sh
ss -lntp | grep 2376
```
You should see a line like this:
```
LISTEN  0  128  0.0.0.0:2376  0.0.0.0:*  users:(("dockerd",pid,fd))
```
If you **don’t** see this, Docker is not properly exposing the TLS API.

To manually test if the Docker API is accessible from **server**, run:
```sh
curl --cacert ~/docker-certs/ca.pem https://192.168.10.9:2376/_ping
```
- If you get `OK`, Docker is reachable.
- If you get an error like "connection refused," Docker is not properly exposing the API.

---

### **3. Check DNS Resolution in Portainer Container**  
If the error message contains something like:
```
lookup tcp on 127.0.0.11:53: no such host
```
it looks like **Portainer’s container is having trouble resolving hostnames**.

Try restarting Portainer:
```sh
docker restart portainer
```
Or, if running via `docker-compose`:
```sh
docker-compose down && docker-compose up -d
```

Then retry the connection in Portainer.

---

### **4. Manually Test the Connection from Inside the Portainer Container**
If the issue persists, check if **Portainer can reach `remote`** from inside the container.

Run this on **server**:
```sh
docker exec -it portainer sh
```
Inside the container, try:
```sh
ping 192.168.10.9
curl --cacert /data/tls/ca.pem https://192.168.10.9:2376/_ping
```
- If `ping` works but `curl` fails, the TLS API might be misconfigured.
- If `ping` fails, the network might be blocking access.

---

### **5. Verify Firewall Rules on `remote`**
If your firewall is blocking port `2376`, allow it:
```sh
sudo ufw allow 2376/tcp
sudo systemctl restart docker
```

---

### **Summary of Fixes to Try**
✅ **Use the correct URL format in Portainer**: `tcp://192.168.10.9:2376`  
✅ **Verify that Docker is listening on port `2376`** (`ss -lntp | grep 2376`)  
✅ **Test API connection manually** (`curl --cacert ca.pem https://192.168.10.9:2376/_ping`)  
✅ **Restart Portainer** (`docker restart portainer`)  
✅ **Check network settings inside Portainer container** (`docker exec -it portainer sh`)  
✅ **Allow port `2376` through the firewall** (`sudo ufw allow 2376/tcp`)  

