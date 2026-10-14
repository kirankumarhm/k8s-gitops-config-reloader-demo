import os
import sys
import time
import psycopg2
import psycopg2.extras
from kubernetes import client, config

def init_k8s():
    try:
        config.load_incluster_config()
        print("[DB-SYNCER] Loaded in-cluster Kubernetes config")
    except Exception:
        config.load_kube_config()
        print("[DB-SYNCER] Loaded local kubeconfig")
    return client.CoreV1Api()

def get_db_connection():
    db_host = os.getenv("DB_HOST", "postgres")
    db_port = int(os.getenv("DB_PORT", "5432"))
    db_name = os.getenv("DB_NAME", "configdb")
    db_user = os.getenv("DB_USER", "postgres")
    db_pass = os.getenv("DB_PASSWORD", "postgres")
    
    return psycopg2.connect(
        host=db_host,
        port=db_port,
        dbname=db_name,
        user=db_user,
        password=db_pass
    )

APP_TO_CONFIGMAP = {
    "springboot-service": "springboot-config",
    "go-service": "go-config",
    "node-service": "node-config",
    "python-service": "python-config",
}

def sync_configs(k8s, namespace):
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute("""
                SELECT application, prop_key, prop_value
                FROM app_properties
                ORDER BY application, prop_key;
            """)
            rows = cur.fetchall()
            
            # Group by application
            app_configs = {}
            for row in rows:
                app = row["application"]
                k = row["prop_key"]
                v = row["prop_value"]
                if app not in app_configs:
                    app_configs[app] = {}
                app_configs[app][k] = v
                
            for app_name, cm_name in APP_TO_CONFIGMAP.items():
                if app_name not in app_configs:
                    continue
                db_data = app_configs[app_name]
                
                try:
                    existing_cm = k8s.read_namespaced_config_map(name=cm_name, namespace=namespace)
                    existing_data = existing_cm.data or {}
                    
                    # Check if different
                    is_different = False
                    for k, v in db_data.items():
                        if existing_data.get(k) != v:
                            is_different = True
                            break
                            
                    if is_different:
                        print(f"[DB-SYNCER] Change detected in DB for {app_name}! Syncing to ConfigMap '{cm_name}'...")
                        new_data = dict(existing_data)
                        new_data.update(db_data)
                        k8s.patch_namespaced_config_map(
                            name=cm_name,
                            namespace=namespace,
                            body={"data": new_data}
                        )
                        print(f"[DB-SYNCER] Successfully patched ConfigMap '{cm_name}' in namespace '{namespace}'.")
                except client.exceptions.ApiException as e:
                    print(f"[DB-SYNCER] Error checking/patching ConfigMap {cm_name}: {e}")
    finally:
        conn.close()

def main():
    namespace = os.getenv("NAMESPACE", "gitops-demo")
    interval = int(os.getenv("SYNC_INTERVAL_SECONDS", "5"))
    print(f"[DB-SYNCER] Starting DB-to-ConfigMap Syncer loop (namespace={namespace}, interval={interval}s)...")
    
    k8s = init_k8s()
    
    while True:
        try:
            sync_configs(k8s, namespace)
        except Exception as e:
            print(f"[DB-SYNCER] Sync iteration error: {e}", file=sys.stderr)
        time.sleep(interval)

if __name__ == "__main__":
    main()
