## Fix breakage test never firing due to event type mismatch

The breakage-against-ponyc-latest workflow was listening for the `shared-docker-linux-builders-updated` repository dispatch event, but the sender dispatches `shared-docker-builders-updated`. The event name mismatch meant the breakage test never triggered when new Docker images were built.
