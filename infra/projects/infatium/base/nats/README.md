# NATS Message Broker Template

Production-ready NATS server with JetStream persistence and clustering.

## What is NATS?

NATS is a high-performance cloud-native messaging system. It provides:

- **Pub/Sub**: Topic-based publish-subscribe messaging
- **Request/Reply**: Synchronous RPC-style communication
- **Queue Groups**: Load-balanced message distribution
- **JetStream**: Persistent streaming with exactly-once delivery
- **Clustering**: High-availability 3-node cluster
- **Lightweight**: Written in Go, minimal resource usage

## Deployment

1. Add to your project:
   ```bash
   ./scripts/add-service.sh
   # Select your project
   # Choose "infra-services"
   # Select "nats"
   ```

2. Deploy:
   ```bash
   kubectl apply -k projects/<product>/overlays/prod
   ```

3. Verify cluster:
   ```bash
   kubectl get pods -n <namespace> -l app=nats
   # Should show 3 pods: nats-0, nats-1, nats-2
   ```

## Configuration

### Connection URLs

**Internal (from pods in same namespace)**:
```
nats://nats:4222
```

**Internal (from other namespaces)**:
```
nats://nats.<namespace>.svc.cluster.local:4222
```

### Cluster Details

- **Replicas**: 3 pods for HA
- **Client Port**: 4222
- **Cluster Port**: 6222 (inter-server communication)
- **Monitoring**: 8222 (HTTP endpoint)

### JetStream Storage

- **Persistent Volume**: 5Gi per pod (15Gi total)
- **Max Memory**: 256MB per pod
- **Max File Storage**: 4GB per pod

## Client Integration

### Go

```go
import "github.com/nats-io/nats.go"

// Connect
nc, err := nats.Connect("nats://nats:4222")
if err != nil {
    log.Fatal(err)
}
defer nc.Close()

// Publish
err = nc.Publish("events.user.created", []byte(`{"user_id": "123"}`))

// Subscribe
sub, err := nc.Subscribe("events.>", func(m *nats.Msg) {
    fmt.Printf("Received: %s\n", string(m.Data))
})
```

### Node.js

```javascript
import { connect } from 'nats'

// Connect
const nc = await connect({
  servers: ['nats://nats:4222']
})

// Publish
nc.publish('events.user.created', JSON.stringify({ user_id: '123' }))

// Subscribe
const sub = nc.subscribe('events.>')
for await (const msg of sub) {
  console.log('Received:', msg.string())
}
```

### Python

```python
import nats
import asyncio

async def main():
    # Connect
    nc = await nats.connect("nats://nats:4222")

    # Publish
    await nc.publish("events.user.created", b'{"user_id": "123"}')

    # Subscribe
    async def message_handler(msg):
        print(f"Received: {msg.data.decode()}")

    await nc.subscribe("events.>", cb=message_handler)

asyncio.run(main())
```

## JetStream (Persistent Streams)

### Create Stream

```bash
# From pod with nats CLI
kubectl exec -it nats-0 -n <namespace> -- nats stream add EVENTS \
  --subjects "events.>" \
  --storage file \
  --retention limits \
  --max-msgs=-1 \
  --max-age=24h
```

### Publish to Stream

```go
js, _ := nc.JetStream()
js.Publish("events.user.created", []byte(`{"user_id": "123"}`))
```

### Consumer with Acknowledgment

```go
js.Subscribe("events.>", func(m *nats.Msg) {
    // Process message
    fmt.Println(string(m.Data))

    // Acknowledge
    m.Ack()
})
```

## Monitoring

### Check Cluster Status

```bash
# View monitoring endpoint
kubectl port-forward -n <namespace> svc/nats 8222:8222

# Open browser: http://localhost:8222
# Or curl: curl http://localhost:8222/varz
```

### Check Logs

```bash
kubectl logs -n <namespace> -l app=nats -f
```

### Health Check

```bash
kubectl exec -it nats-0 -n <namespace> -- \
  wget -qO- http://localhost:8222/healthz
```

## Common Patterns

### Event Bus (Pub/Sub)

```
events.user.created     → User service publishes
events.user.created     → Email service subscribes
events.user.created     → Analytics service subscribes
```

### Work Queue (Load Balancing)

```
jobs.thumbnail.generate → API publishes 100 jobs
jobs.thumbnail.>        → 3 worker pods (queue group) share load
```

### Request/Reply (RPC)

```go
// Server
nc.Subscribe("api.user.get", func(m *nats.Msg) {
    user := getUser(m.Data)
    m.Respond([]byte(user))
})

// Client
resp, _ := nc.Request("api.user.get", []byte("123"), 1*time.Second)
fmt.Println(string(resp.Data))
```

## Performance Tuning

### For High Throughput

Edit `configmap.yml`:

```yaml
max_payload: 10MB           # Larger messages
max_connections: 10000      # More concurrent clients
write_deadline: "30s"       # Slower clients
```

### For Low Latency

```yaml
max_payload: 256KB          # Smaller messages
write_deadline: "2s"        # Fast client timeouts
```

## Security Notes

1. **Network Policies**: NATS is internal-only by default
2. **Authentication**: Add auth tokens if needed (see NATS docs)
3. **TLS**: Enable TLS for production if sharing across untrusted namespaces

## Troubleshooting

### Issue: Pods not forming cluster

Check logs for cluster connection errors:
```bash
kubectl logs nats-0 -n <namespace> | grep cluster
```

Verify DNS resolution:
```bash
kubectl exec -it nats-0 -n <namespace> -- \
  nslookup nats-1.nats.<namespace>.svc.cluster.local
```

### Issue: JetStream not persisting

Check PVC status:
```bash
kubectl get pvc -n <namespace> -l app=nats
```

Verify storage class:
```bash
kubectl get sc
```

### Issue: High memory usage

Reduce JetStream limits in `configmap.yml`:
```yaml
jetstream {
  max_memory_store: 128MB
  max_file_store: 2GB
}
```

## Comparison with RabbitMQ

| Feature | NATS | RabbitMQ |
|---------|------|----------|
| **Language** | Go | Erlang |
| **Memory** | ~10MB | ~100MB+ |
| **Throughput** | Millions msg/s | Hundreds of thousands msg/s |
| **Protocol** | Native TCP | AMQP 0.9.1 |
| **Clustering** | Built-in | Requires plugin |
| **Streams** | JetStream (optional) | Persistent queues |
| **Use Case** | Microservices, events | Enterprise workflows |

## References

- [NATS Documentation](https://docs.nats.io/)
- [JetStream Guide](https://docs.nats.io/nats-concepts/jetstream)
- [NATS by Example](https://natsbyexample.com/)
