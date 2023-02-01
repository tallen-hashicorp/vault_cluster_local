# Running Vault Localy

```bash
vault server -dev
```

```bash
vault server -dev -dev-root-token-id=root -dev-ha -dev-transactional -dev-listen-address=127.0.0.1:8200
```

## Simple Method

* In memory storage - not persistent
* Initialised and unsealed
* HTTP plaintext
* Doesn't support replication - storage needs to support transactional updates e.g. RAFT/Consul

```bash
vault server -dev
export VAULT_ADDR=http://127.0.0.1:8200
```

## Simple Method - Extra
* In memory storage - with added transactional update support!
* Hardcodes root token
* Can be used for testing replication
* How Russ runs Vault 99% of the time

```bash
vault server -dev -dev-root-token-id=root -dev-ha -dev-transactional -dev-listen-address=127.0.0.1:8200
export VAULT_ADDR=http://127.0.0.1:8200
```

## Hack 1 - Avoiding Port Collisions

* Can use different ports for `-dev-listen-address` e.g. 127.0.0.1:8210 to avoid collisions
* Or create additional addresses on loopback interface
* To add: sudo ifconfig lo0 alias 127.0.0.2
    * To remove: `sudo ifconfig lo0 -alias 127.0.0.2`
    * To remove: `sudo ifconfig lo0 -alias 127.0.0.2`

```bash
vault server -dev -dev-root-token-id=root -dev-ha -dev-transactional -dev-listen-address=127.0.0.1:8210
export VAULT_ADDR=http://127.0.0.1:8210
```

## Enable High Availability
* Requires persistent storage backend - in-memory no longer an option
* Preferred options are RAFT, Consul (or file_transactional 🤫)

```bash
consul agent -dev
vault server -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:8200 -dev-consul
vault server -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:8210 -dev-consul -dev-skip-init
vault server -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:8220 -dev-consul -dev-skip-init
```

*(Remember to unseal the 2nd and 3rd Vault "nodes")*


## Hack #2 - Easy TLS certs & "DNS"
* mkcert - makes locally-trusted development certificates [https://github.com/FiloSottile/mkcert](https://github.com/FiloSottile/mkcert)
* Run once to add CA to local Trust Store - mkcert -install

```bash 
mkcert vault.local vault1.local vault2.local vault3.local 127.0.0.1 127.0.0.2 127.0.0.3
```

* hosts - manages hosts file entries - [https://github.com/xwmx/hosts](https://github.com/xwmx/hosts)

```bash
hosts --auto-sudo add 127.0.0.1 vault1.local
hosts --auto-sudo add 127.0.0.2 vault2.local
hosts --auto-sudo add 127.0.0.3 vault3.local
```

## Using RAFT + TLS
* Requires use of config file

```bash
vault server -config vault1.hcl
export VAULT_ADDR=https://127.0.0.1:8200
vault operator init -key-shares=1 -key-threshold=1
vault operator unseal
```

### Docs
* Listener - [https://www.vaultproject.io/docs/configuration/listener/tcp](https://www.vaultproject.io/docs/configuration/listener/tcp)
* Storage - [https://www.vaultproject.io/docs/configuration/storage/raft](https://www.vaultproject.io/docs/configuration/storage/raft)

## Adding in Auto-Unseal
* Multiple auto-unseal methods - HSMs & Cloud KMS
* Easiest to use locally is Vault Transit Auto-Unseal

```bash
vault server -dev -dev-root-token-id=root -dev-ha -dev-transactional -dev-listen-address=127.0.0.4:8200
export VAULT_ADDR=http://127.0.0.4:8200
vault secrets enable transit
vault write -f transit/keys/autounseal
export VAULT_ADDR=https://127.0.0.1:8200
vault operator init -recovery-shares=1 -recovery-threshold=1
```

## Load Balancing
* Lots of options for load balancing - HAProxy, nginx, entire Kubernetes stack...
* Fabio - [https://fabiolb.net/](https://fabiolb.net/)
* Single binary
* Uses Consul catalog for configuration
* Add `service_registration` stanza to Vault config files
    * `service_tags = "urlprefix-:9200 proto=tcp"`
* `fabio -proxy.addr=":9200;proto=tcp"`

## Final Setup
![Final Setip Image](docs/Screenshot%202023-02-01%20at%2015.58.56.png)

## Run by hand
```bash
mkdir -p data/node1
mkdir -p data/node2
mkdir -p data/node3

sudo ifconfig lo0 alias 127.0.0.2
sudo ifconfig lo0 alias 127.0.0.3
sudo ifconfig lo0 alias 127.0.0.4
ifconfig lo0

hosts --auto-sudo add 127.0.0.1 vault1.local
hosts --auto-sudo add 127.0.0.2 vault2.local
hosts --auto-sudo add 127.0.0.3 vault3.local
hosts --auto-sudo add 127.0.0.4 vault4.local

mkcert -install
mkcert vault.local vault1.local vault2.local vault3.local 127.0.0.1 127.0.0.2 127.0.0.3

consul agent -dev

vault server -dev -dev-root-token-id=root -dev-listen-address=vault4.local:8200 -dev-consul 

VAULT_ADDR=http://vault4.local:8200 vault secrets enable transit

vault server  -config config/vault1.hcl

vault server  -config config/vault2.hcl

vault server  -config config/vault3.hcl

fabio -proxy.addr=":9200;proto=tcp"

VAULT_ADDR=https://vault1.local:8200 vault operator init -recovery-shares=1 -recovery-threshold=1

VAULT_ADDR=https://vault1.local:8200 vault login

VAULT_ADDR=https://vault1.local:8200 vault operator members
VAULT_ADDR=https://vault1.local:8200 vault operator raft list-peers
```

## Clean by hand
```bash
rm -r data

hosts --auto-sudo remove 127.0.0.1 vault1.local
hosts --auto-sudo remove 127.0.0.2 vault2.local
hosts --auto-sudo remove 127.0.0.3 vault3.local
hosts --auto-sudo remove 127.0.0.4 vault4.local

sudo ifconfig lo0 -alias 127.0.0.2
sudo ifconfig lo0 -alias 127.0.0.3
sudo ifconfig lo0 -alias 127.0.0.4
ifconfig lo0
```