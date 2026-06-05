const parts = window.location.pathname.split("/").filter(Boolean);
const route = parts[0];

if (route === "rating") {
  import("./rating.js").then(({ start }) => start());
} else {
  import("./session.js").then(({ start }) => start());
}
