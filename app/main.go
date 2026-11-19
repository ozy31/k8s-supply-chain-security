// A minimal HTTP service used as the workload whose image is built, signed,
// attested and admitted. It reports the build metadata stamped at link time
// so a running pod can be traced back to the commit that produced it.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

var (
	version = "dev"
	commit  = "unknown"
)

func main() {
	addr := ":8080"
	if v := os.Getenv("LISTEN_ADDR"); v != "" {
		addr = v
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"version": version, "commit": commit})
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("listening on %s (version=%s commit=%s)", addr, version, commit)
	log.Fatal(srv.ListenAndServe())
}
