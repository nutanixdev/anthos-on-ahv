import yaml
import os

from yaml import load, dump
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

TEMPLATE_PATH = os.getenv("ANTHOS_TEMPLATE_PATH")
SSH_KEY = os.getenv("ANTHOS_SSH_KEY")
CLUSTER_TYPE = os.getenv("ANTHOS_CLUSTER_TYPE")
CONTROLPLANE_ADDRESSES = os.getenv("ANTHOS_CONTROLPLANE_ADDRESSES").split(",")
CONTROLPLANE_VIP = os.getenv("ANTHOS_CONTROLPLANE_VIP")
PODS_NETWORK = os.getenv("ANTHOS_PODS_NETWORK")
SERVICES_NETWORK = os.getenv("ANTHOS_SERVICES_NETWORK")
INGRESS_VIP = os.getenv("ANTHOS_INGRESS_VIP")
LB_ADDRESSPOOL = os.getenv("ANTHOS_LB_ADDRESSPOOL")
LVPNODEMOUNTS = os.getenv("ANTHOS_LVPNODEMOUNTS")
LVPSHARE = os.getenv("ANTHOS_LVPSHARE")
LOGINUSER = os.getenv("ANTHOS_LOGINUSER")
WORKERNODES_ADDRESSES = os.getenv("ANTHOS_WORKERNODES_ADDRESSES").split(",")


with open(TEMPLATE_PATH, 'r+') as f:
  stream = f.read()
  data = list(yaml.load_all(stream, Loader=yaml.SafeLoader))

  # Keys
  data[0]['sshPrivateKeyPath'] = SSH_KEY

  # Control plane config
  data[2]['spec']['type'] = CLUSTER_TYPE

  data[2]['spec']['controlPlane']['nodePoolSpec']['nodes'] = []
  for address in CONTROLPLANE_ADDRESSES:
    data[2]['spec']['controlPlane']['nodePoolSpec']['nodes'].append({
      'address': address
    })

  # Kubernetes networks
  data[2]['spec']['clusterNetwork']['pods']['cidrBlocks'][0] = PODS_NETWORK
  data[2]['spec']['clusterNetwork']['services']['cidrBlocks'][0] = SERVICES_NETWORK

  # Kubernetes load balancing
  data[2]['spec']['loadBalancer']['vips']['controlPlaneVIP'] = CONTROLPLANE_VIP
  data[2]['spec']['loadBalancer']['vips']['ingressVIP'] = INGRESS_VIP

  pool = {
    "name": "pool1",
    "addresses": [
      LB_ADDRESSPOOL
    ]
  }
  data[2]['spec']['loadBalancer']['addressPools'] = [pool]

  # Local storage configuration
  data[2]['spec']['storage']['lvpNodeMounts']['path'] = LVPNODEMOUNTS
  data[2]['spec']['storage']['lvpShare']['path'] = LVPSHARE

  # Authentication
  data[2]['spec']['nodeAccess'] = {}
  data[2]['spec']['nodeAccess']['loginUser'] = LOGINUSER

  # Worker nodes config
  data[3]['spec']['nodes'] = []
  for address in WORKERNODES_ADDRESSES:
    data[3]['spec']['nodes'].append({
      'address': address
    })

  f.seek(0)
  f.write(yaml.dump_all(data, explicit_start=True))
  f.truncate()