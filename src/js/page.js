'use strict';
let pages = [window.location.pathname];
let switchDirectionWindowWidth = 900;
let animationLength = 200;

var URI = require('urijs');

var tempNetwork;

function collectConnectedNodes(
    allNodes, baseNode, distance, alreadyConnected) {
    if (distance < 1) {
        return new Set([baseNode]); // base case for recursion
    }

    let connectedNodes = new Set([baseNode]);
    const neighbours = tempNetwork.getConnectedNodes(baseNode);

    for (let i = 0; i < neighbours.length; i++) {
        // Skip this node if we've already seen it. Helps with the performance.
        if (alreadyConnected && alreadyConnected.has(neighbours[i])) continue;
        var neighbourConnectedNodes = collectConnectedNodes(
            allNodes, neighbours[i], distance - 1, connectedNodes);
        for (let node of neighbourConnectedNodes) {
            connectedNodes.add(node);
        }
    }
    return connectedNodes;
}


function stackNote(href, level) {
  level = Number(level) || pages.length;
  if(href instanceof SVGAnimatedString){
    href = href.baseVal;
    if(href.indexOf("../") === 0){
      href = href.substring(3);
    }
  }
  href = URI(href);
  let uri = URI(window.location);
  let stacks = [];
  if (uri.hasQuery("stackedNotes")) {
    stacks = uri.query(true).stackedNotes;
    if (!Array.isArray(stacks)) {
      stacks = [stacks];
    }
    stacks = stacks.slice(0, level - 1);
  }
  stacks.push(href.path());
  uri.setQuery("stackedNotes", stacks);

  let old_stacks = stacks.slice(0, level - 1);
  let state = { stacks: old_stacks, level: level };
  window.history.pushState(state, "", uri.href());
}

function unstackNotes(level) {
  let container = document.querySelector(".ds-grid");
  let children = Array.prototype.slice.call(container.children);

  for (let i = level; i < pages.length; i++) {
    container.removeChild(children[i]);
    destroyPreviews(children[i]);
  }
  pages = pages.slice(0, level);
}

function fetchNote(href, level, animate = false) {

  if(href instanceof SVGAnimatedString){
    href = href.baseVal;
  }

  if(href.indexOf("../") === 0){
    href = href.substring(3);
  }

  level = Number(level) || pages.length;

  const request = new Request(href);
  fetch(request)
    .then((response) => response.text())
    .then((text) => {
      unstackNotes(level);
      let container = document.querySelector(".ds-grid");
      let fragment = document.createElement("template");
      fragment.innerHTML = text;
      let element = fragment.content.querySelector(".page");
      container.appendChild(element);
      pages.push(href);

      setTimeout(
        function (element, level) {
          element.dataset.level = level + 1;
          initializePreviews(element, level + 1);
          element.scrollIntoView();
          if (animate) {
            element.animate([{ opacity: 0 }, { opacity: 1 }], animationLength);
          }

          if (window.MathJax) {
            window.MathJax.Hub.Queue(["Typeset", MathJax.Hub, element])
          }
        }.bind(null, element, level),
        10
      );

      updateLinkStatuses();
    });
}

function updateLinkStatuses() {
  let links = Array.prototype.slice.call(
    document.querySelectorAll("a[data-uuid]")
  );

  links.forEach(function (link) {
    if (pages.indexOf(link.dataset.uuid) !== -1) {
      link.classList.add("linked");
      if (link._tippy) link._tippy.disable();
    } else {
      link.classList.remove("linked");
      if (link._tippy) link._tippy.enable();
    }
  });
}

function destroyPreviews(page) {
  let links = Array.prototype.slice.call(page.querySelectorAll("a[data-uuid]"));

  links.forEach(function (link) {
    if (link.hasOwnProperty("_tippy")) {
      link._tippy.destroy();
    }
  });
}

let tippyOptions = {
  allowHTML: true,
  theme: "light",
  interactive: true,
  interactiveBorder: 10,
  delay: 500,
  touch: ["hold", 500],
  maxWidth: "none",
  inlinePositioning: false,
  placement: "right",
};

function createPreview(link, html, overrideOptions) {
  if(link.href instanceof SVGAnimatedString){
    return;
  }
  let level = Number(link.dataset.level);
  let iframe = document.createElement('iframe');
  iframe.width = "400px";
  iframe.height = "300px";
  iframe.srcdoc = html;
  let tip = tippy(
    link,
    Object.assign(
      {},
      tippyOptions,
      {
        content: iframe.outerHTML
          // '<iframe width="400px" height="300px" srcdoc="' +
          //     escape(html) +
          // '"></iframe>',
      },
      overrideOptions
    )
  );
}

function initializePreviews(page, level) {
  level = level || pages.length;

  let links = Array.prototype.slice.call(page.querySelectorAll("a:not(.rooter)"));

  let fetchHelper = async function (element) {
    let rawHref = element.getAttribute("xlink:href");
    if(!rawHref)
      rawHref = element.getAttribute("href");
    if(rawHref && rawHref.indexOf("../") === 0)
      rawHref = rawHref.substring(3);

    if(rawHref && rawHref.indexOf("org-protocol://") === 0){
      return;
    }

    element.dataset.level = level;
    if (
      rawHref &&
      !(
        rawHref.indexOf("http://") === 0 ||
        rawHref.indexOf("https://") === 0 ||
        rawHref.indexOf("#") === 0 ||
        rawHref.includes(".pdf") ||
        rawHref.includes(".svg")
      )
    ) {
        var prefetchLink = rawHref;//element.href;
        async function myFetch() {
            let response = await fetch(prefetchLink);
            let fragment = document.createElement("template");
            fragment.innerHTML = await response.text();
            let ct = await response.headers.get("content-type");
          if (ct.includes("text/html")) {

            let outerHTML="";
            fragment
              .content
              .querySelectorAll("#content > :not(.graph)")
              .forEach( x => outerHTML += x.outerHTML);

            createPreview(element, outerHTML, {
              placement:
              window.innerWidth > switchDirectionWindowWidth
                ? "right"
                : "top",
            });

            element.addEventListener("click", function (e) {
              if (!e.ctrlKey && !e.metaKey) {
                e.preventDefault();
                stackNote(element.href, this.dataset.level);
                fetchNote(element.href, this.dataset.level, true);
              }
            });
          };
        }
      return myFetch();
    }
  }

  let svg = page.querySelector("object");

  let onsvgload = () => {
    let svglinks = Array.prototype
        .slice
        .call(svg
              .contentWindow
              .document
              .querySelectorAll("a"));
    svglinks.forEach(fetchHelper);
  };

  if(svg && !svg.contentWindow){
    svg.onload = onsvgload;
  }else if(svg){
    onsvgload();
  }

  links.forEach(fetchHelper);
}

window.addEventListener("popstate", function (event) {
  // TODO: check state and pop pages if possible, rather than reloading.
  window.location = window.location; // this reloads the page.
});

window.onload = function () {
  //loadNetworkNodes();
  initializePreviews(document.querySelector(".page"));

  let uri = URI(window.location);
  if (uri.hasQuery("stackedNotes")) {
    let stacks = uri.query(true).stackedNotes;
    if (!Array.isArray(stacks)) {
      stacks = [stacks];
    }
    for (let i = 1; i <= stacks.length; i++) {
      fetchNote(stacks[i - 1], i);
    }
  }
};
