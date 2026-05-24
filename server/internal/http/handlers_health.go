package http

import (
	"net/http"

	"sprout/server/internal/notification"
)

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
	})
}

func (s *Server) handleMetrics(w http.ResponseWriter, _ *http.Request) {
	workerMetrics := notification.DeliveryWorkerMetricsSnapshot{}
	if s.pushDeliveryWorker != nil {
		workerMetrics = s.pushDeliveryWorker.MetricsSnapshot()
	}
	writeText(w, http.StatusOK, metricsText(s.cfg, s.metrics.Snapshot(), workerMetrics))
}
