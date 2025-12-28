// K8s development - Frontend talks to K8s backend via port-forward or LoadBalancer
export const environment = {
  production: false,
  backendUrl: 'http://localhost:3000', // Use this when port-forwarding to K8s backend
  // Or uncomment below to use LoadBalancer IP directly:
  // backendUrl: 'http://34.75.143.108:3000',
};
