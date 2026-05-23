import { authPath } from "./path/auth.path";
import { tripPath } from "./path/trip.path";

const openApiSpec = {
  openapi: "3.0.0",
  info: { title: "Wayfarer API", version: "1.0.0" },
  servers: [{ url: "http://localhost:3000/api" }],
  paths: {
    ...authPath,
    ...tripPath,
  },
  components: {
    securitySchemes: {
      BearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
  },
};

export default openApiSpec;