(ns hello-clj.main
  (:gen-class)
  (:require [org.httpkit.server :as server]))

(defn -main []
  (server/run-server
   (fn [req] {:status 200
              :headers {"Content-Type" "text/plain"}
              :body "Hello Clojure!"})
   {:port 8000})
  @(promise))
