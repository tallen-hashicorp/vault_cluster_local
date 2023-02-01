storage "raft" {
  path    = "data/node3"
  node_id = "node3"
  retry_join {
    leader_api_addr = "https://vault1.local:8200"
  }
  retry_join {
    leader_api_addr = "https://vault2.local:8200"
  }
}

listener "tcp" {
  address     = "vault3.local:8200"
  tls_disable = 0
  tls_cert_file = "vault.local+6.pem"
  tls_key_file = "vault.local+6-key.pem"
  tls_disable_client_certs = "true"
}

service_registration "consul" {
  address = "127.0.0.1:8500"
  service_tags = "urlprefix-:9200 proto=tcp"
}

seal "transit" {
  address            = "http://vault4.local:8200"
  token              = "root"
  disable_renewal    = "false"

  // Key configuration
  key_name           = "autounseal"
  mount_path         = "transit/"
  namespace          = "ns1/"
  tls_skip_verify = "true"
}

api_addr = "https://vault3.local:8200"
cluster_addr = "https://vault3.local:8201"
ui = true
disable_mlock = "true"