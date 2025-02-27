# Homelab Portainer

To deploy Portainer locally using `docker-compose` and add other machine(s) for managing, follow the steps below:

### 1. **Create a `docker-compose.yml` file**
On the **server**, use the [`docker-compose.yml`](./docker-compose.yml) file.
Adjust if needed.

### 2. **Deploy Portainer**
Run the following command:
```sh
docker-compose up -d
```
This will pull the latest Portainer image and start the container in detached mode.

### 3. **Access Portainer**
Once running, open your browser and go to:
```
https://<server-ip>:9443
```
You’ll be prompted to create an admin account.

### 4. **Add the Second Machine**
To manage your second machine:
- Go to **Environments** in Portainer.
- Click **Add Environment**.
- Choose **Docker** → **Remote**.
- Enter the **IP address** of your second machine and port `2375` (if the Docker API is exposed).
- Click **Connect** and save.

Now, Portainer on your **server** will manage both machines! 🚀

For more details regarding the setup of the remote (using TLS or not), follow the instructions [here](./configure-remote.md).

## Autostart
To configure the service to start on reboot, execute the following:
```sh
chmod +x configure-service.sh
./configure-service.sh "./homelab-portainer.service" "WorkingDirectory" $(pwd)
sudo ln -s homelab-portainer.service /etc/systemd/system/homelab-portainer.service
sudo systemctl daemon-reload
sudo systemctl enable homelab-portainer.service
sudo systemctl start homelab-portainer.service
```