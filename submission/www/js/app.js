/* SOS Now
   Cordova web app (www). The brief allows App.js or a similar approach.
   This file is plain JavaScript in that same Cordova www structure.
   Reports are saved on the phone and shown to every account on this install
   as soon as they are submitted. There is no separate approval step. */

const CATEGORIES = ["Accident", "Fighting", "Rioting", "Robbery", "Fire", "Medical", "Flood", "Kidnapping", "Other"];

const db = {
    users: [],
    incidents: [],
    alerts: []
};

const ui = {
    screen: "auth",
    mode: "login",
    category: "All",
    detailId: null,
    error: "",
    banner: null,
    busy: false
};

function load() {
    db.users = read("users", []);
    db.incidents = read("incidents", []);
    db.alerts = read("alerts", []);
    ui.user = read("session", null);
    if (ui.user) ui.screen = "incidents";
}

function read(key, fallback) {
    try {
        const value = JSON.parse(localStorage.getItem("sosnow." + key));
        return value === null ? fallback : value;
    } catch (err) {
        return fallback;
    }
}

function write(key, value) {
    localStorage.setItem("sosnow." + key, JSON.stringify(value));
}

function saveAll() {
    write("users", db.users);
    write("incidents", db.incidents);
    write("alerts", db.alerts);
    write("session", ui.user);
}

function esc(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (ch) {
        return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
}

function phoneOf(raw) {
    let digits = String(raw || "").replace(/\D/g, "");
    if (digits.indexOf("234") === 0) digits = digits.slice(3);
    if (digits.indexOf("0") === 0) digits = digits.slice(1);
    if (digits.length !== 10) throw new Error("Enter a valid Nigerian phone number");
    return "+234" + digits;
}

async function hashPassword(password, salt) {
    const bytes = new TextEncoder().encode(salt + ":" + password);
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(digest)).map(function (n) {
        return n.toString(16).padStart(2, "0");
    }).join("");
}

function uid() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

function when(iso) {
    const date = new Date(iso);
    return date.toLocaleString(undefined, { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function unread() {
    if (!ui.user) return 0;
    return db.alerts.filter(function (alert) {
        return alert.userId === ui.user.id && !alert.read;
    }).length;
}

function visibleIncidents() {
    return db.incidents.filter(function (incident) {
        if (ui.screen === "mine") return incident.userId === ui.user.id;
        if (ui.category !== "All" && incident.category !== ui.category) return false;
        return true;
    }).sort(function (a, b) {
        return b.createdAt.localeCompare(a.createdAt);
    });
}

function render() {
    const root = document.getElementById("app");
    const banner = ui.banner ? '<div class="banner"><span>' + esc(ui.banner) + '</span><button type="button" id="dismiss">Dismiss</button></div>' : "";
    if (!ui.user) {
        root.innerHTML = authHtml();
        bindAuth();
        return;
    }
    root.innerHTML = banner + screenHtml() + tabsHtml();
    bindShell();
}

function authHtml() {
    const creating = ui.mode === "register";
    return '<section class="screen auth">' +
        '<div class="mark">!</div>' +
        "<h2>SOS Now</h2>" +
        '<p class="lede">Report an accident, fight, riot, or other incident. Other people who sign in on this phone can see it straight away.</p>' +
        '<div class="switch"><button type="button" id="show-login" class="' + (creating ? "" : "on") + '">Log in</button>' +
        '<button type="button" id="show-register" class="' + (creating ? "on" : "") + '">Create account</button></div>' +
        (creating ? '<label>Name<input id="name" autocomplete="name"></label>' : "") +
        '<label>Phone number<input id="phone" inputmode="tel" placeholder="0803 123 4567" autocomplete="tel"></label>' +
        '<label>Password<input id="password" type="password" autocomplete="' + (creating ? "new-password" : "current-password") + '"></label>' +
        (ui.error ? '<p class="error">' + esc(ui.error) + "</p>" : "") +
        '<button class="primary" id="submit-auth" ' + (ui.busy ? "disabled" : "") + ">" + (creating ? "Create account" : "Log in") + "</button>" +
        "</section>";
}

function screenHtml() {
    if (ui.screen === "report") return reportHtml();
    if (ui.screen === "alerts") return alertsHtml();
    if (ui.screen === "detail") return detailHtml();
    return listHtml();
}

function listHtml() {
    const mine = ui.screen === "mine";
    const items = visibleIncidents();
    const chips = mine ? "" : '<div class="chips">' + ["All"].concat(CATEGORIES).map(function (category) {
        return '<button type="button" data-category="' + esc(category) + '" class="' + (ui.category === category ? "on" : "") + '">' + esc(category) + "</button>";
    }).join("") + "</div>";
    const cards = items.length ? items.map(cardHtml).join("") : '<p class="empty">' + (mine ? "You have not submitted an incident yet." : "No incidents in this category yet.") + "</p>";
    return '<header class="top"><div><h1>SOS Now</h1><p>' + esc(ui.user.name) + "</p></div>" +
        '<button type="button" id="logout">Log out</button></header>' +
        '<section class="screen"><p class="lede">' + (mine ? "Incidents you have submitted." : "A new incident is listed here as soon as it is submitted.") + "</p>" +
        chips + cards + "</section>";
}

function cardHtml(incident) {
    return '<button type="button" class="card" data-id="' + esc(incident.id) + '">' +
        '<img alt="" src="' + incident.photo + '">' +
        "<span><span class=\"tag\">" + esc(incident.category) + "</span><strong>" + esc(incident.placeName) + "</strong>" +
        '<span class="meta">' + Number(incident.latitude).toFixed(5) + ", " + Number(incident.longitude).toFixed(5) + "<br>" +
        esc(when(incident.createdAt)) + " · " + esc(incident.reporterName) + "</span></span></button>";
}

function reportHtml() {
    const choices = CATEGORIES.map(function (category) {
        return '<button type="button" class="choice" data-choice="' + esc(category) + '">' + esc(category) + "</button>";
    }).join("");
    return '<header class="top"><div><h1>Report</h1><p>' + esc(ui.user.name) + "</p></div>" +
        '<button type="button" id="logout">Log out</button></header>' +
        '<section class="screen"><p class="lede">This report is shared with the other accounts on this phone as soon as you send it.</p>' +
        "<label>Category</label><div class=\"chips\" id=\"choices\">" + choices + "</div>" +
        '<label>Place<input id="place" placeholder="Ikeja Along, Lagos"></label>' +
        '<label>What is happening?<textarea id="description"></textarea></label>' +
        "<label>Picture</label><input id=\"photo\" type=\"file\" accept=\"image/*\">" +
        '<div class="row"><label>Latitude<input id="lat" inputmode="decimal"></label><label>Longitude<input id="lng" inputmode="decimal"></label></div>' +
        '<button class="ghost" type="button" id="locate">Use my location</button>' +
        (ui.error ? '<p class="error">' + esc(ui.error) + "</p>" : "") +
        '<button class="primary" id="send" ' + (ui.busy ? "disabled" : "") + ">Submit incident</button></section>";
}

function alertsHtml() {
    const rows = db.alerts.filter(function (alert) {
        return alert.userId === ui.user.id;
    }).sort(function (a, b) {
        return b.createdAt.localeCompare(a.createdAt);
    });
    const body = rows.length ? rows.map(function (alert) {
        return '<button type="button" class="alert ' + (alert.read ? "" : "unread") + '" data-alert="' + esc(alert.id) + '" data-incident="' + esc(alert.incidentId) + '"><strong>' +
            esc(alert.message) + '</strong><br><span class="meta">' + esc(when(alert.createdAt)) + "</span></button>";
    }).join("") : '<p class="empty">No alerts yet. When another account submits an incident, it shows up here.</p>';
    return '<header class="top"><div><h1>Alerts</h1><p>' + esc(ui.user.name) + "</p></div>" +
        '<button type="button" id="logout">Log out</button></header><section class="screen">' + body + "</section>";
}

function detailHtml() {
    const incident = db.incidents.find(function (item) { return item.id === ui.detailId; });
    if (!incident) return '<section class="screen"><p>That incident is no longer here.</p></section>';
    const pad = 0.01;
    const bbox = [incident.longitude - pad, incident.latitude - pad, incident.longitude + pad, incident.latitude + pad].join(",");
    const map = "https://www.openstreetmap.org/export/embed.html?bbox=" + encodeURIComponent(bbox) + "&layer=mapnik&marker=" + incident.latitude + "," + incident.longitude;
    return '<header class="top"><button type="button" id="back">Back</button><h1>' + esc(incident.category) + "</h1><span></span></header>" +
        '<section class="screen detail"><img class="hero" alt="Picture of the incident" src="' + incident.photo + '">' +
        "<h2>" + esc(incident.placeName) + "</h2>" +
        '<p class="meta">' + esc(when(incident.createdAt)) + " · Reported by " + esc(incident.reporterName) + "</p>" +
        "<p>" + Number(incident.latitude).toFixed(5) + ", " + Number(incident.longitude).toFixed(5) + "</p>" +
        '<iframe class="map" title="Incident location" src="' + map + '"></iframe>' +
        '<p class="fine">Map data © OpenStreetMap</p><p>' + esc(incident.description) + "</p></section>";
}

function tabsHtml() {
    const count = unread();
    const tabs = [
        ["incidents", "Incidents"],
        ["report", "Report"],
        ["alerts", "Alerts" + (count ? " (" + count + ")" : "")],
        ["mine", "Mine"]
    ];
    return '<nav class="tabs">' + tabs.map(function (tab) {
        return '<button type="button" data-tab="' + tab[0] + '" class="' + (ui.screen === tab[0] ? "on" : "") + '">' + tab[1] + "</button>";
    }).join("") + "</nav>";
}

function bindAuth() {
    document.getElementById("show-login").onclick = function () { ui.mode = "login"; ui.error = ""; render(); };
    document.getElementById("show-register").onclick = function () { ui.mode = "register"; ui.error = ""; render(); };
    document.getElementById("submit-auth").onclick = ui.mode === "register" ? register : login;
}

function bindShell() {
    const logout = document.getElementById("logout");
    if (logout) logout.onclick = function () { ui.user = null; ui.banner = null; saveAll(); ui.screen = "auth"; render(); };
    const dismiss = document.getElementById("dismiss");
    if (dismiss) dismiss.onclick = function () { ui.banner = null; render(); };
    document.querySelectorAll("[data-tab]").forEach(function (button) {
        button.onclick = function () {
            ui.screen = button.getAttribute("data-tab");
            ui.error = "";
            render();
        };
    });
    document.querySelectorAll("[data-category]").forEach(function (button) {
        button.onclick = function () {
            ui.category = button.getAttribute("data-category");
            render();
        };
    });
    document.querySelectorAll("[data-id]").forEach(function (button) {
        button.onclick = function () {
            ui.detailId = button.getAttribute("data-id");
            ui.screen = "detail";
            render();
        };
    });
    document.querySelectorAll("[data-alert]").forEach(function (button) {
        button.onclick = function () {
            const alert = db.alerts.find(function (item) { return item.id === button.getAttribute("data-alert"); });
            if (alert) alert.read = true;
            saveAll();
            ui.detailId = button.getAttribute("data-incident");
            ui.screen = "detail";
            render();
        };
    });
    const back = document.getElementById("back");
    if (back) back.onclick = function () { ui.screen = "incidents"; render(); };
    document.querySelectorAll("[data-choice]").forEach(function (button) {
        button.onclick = function () {
            ui.chosen = button.getAttribute("data-choice");
            document.querySelectorAll("[data-choice]").forEach(function (other) { other.classList.toggle("on", other === button); });
        };
    });
    const locate = document.getElementById("locate");
    if (locate) locate.onclick = useLocation;
    const send = document.getElementById("send");
    if (send) send.onclick = submitIncident;
}

async function register() {
    ui.error = "";
    const name = document.getElementById("name").value.trim().replace(/\s+/g, " ");
    const password = document.getElementById("password").value;
    let phone;
    try { phone = phoneOf(document.getElementById("phone").value); }
    catch (err) { ui.error = err.message; render(); return; }
    if (name.length < 2) { ui.error = "Enter your name"; render(); return; }
    if (password.length < 6) { ui.error = "Use at least 6 characters"; render(); return; }
    if (db.users.some(function (user) { return user.phone === phone; })) {
        ui.error = "An account with this phone number already exists";
        render();
        return;
    }
    const salt = uid();
    db.users.push({ id: uid(), name: name, phone: phone, salt: salt, passwordHash: await hashPassword(password, salt) });
    ui.user = { id: db.users[db.users.length - 1].id, name: name, phone: phone };
    ui.screen = "incidents";
    saveAll();
    render();
}

async function login() {
    ui.error = "";
    let phone;
    try { phone = phoneOf(document.getElementById("phone").value); }
    catch (err) { ui.error = "Phone number or password is incorrect"; render(); return; }
    const password = document.getElementById("password").value;
    const user = db.users.find(function (item) { return item.phone === phone; });
    if (!user || await hashPassword(password, user.salt) !== user.passwordHash) {
        ui.error = "Phone number or password is incorrect";
        render();
        return;
    }
    ui.user = { id: user.id, name: user.name, phone: user.phone };
    ui.screen = "incidents";
    const fresh = db.alerts.find(function (alert) { return alert.userId === user.id && !alert.read; });
    ui.banner = fresh ? fresh.message : null;
    saveAll();
    render();
}

function useLocation() {
    const lat = document.getElementById("lat");
    const lng = document.getElementById("lng");
    if (!navigator.geolocation) {
        ui.error = "This phone did not share a location. Type the latitude and longitude.";
        render();
        return;
    }
    navigator.geolocation.getCurrentPosition(function (position) {
        lat.value = position.coords.latitude.toFixed(6);
        lng.value = position.coords.longitude.toFixed(6);
    }, function () {
        ui.error = "Location permission was denied. Type the latitude and longitude.";
        render();
    }, { enableHighAccuracy: true, timeout: 10000 });
}

function submitIncident() {
    ui.error = "";
    const place = document.getElementById("place").value.trim().replace(/\s+/g, " ");
    const description = document.getElementById("description").value.trim().replace(/\s+/g, " ");
    const latitude = Number(document.getElementById("lat").value);
    const longitude = Number(document.getElementById("lng").value);
    const file = document.getElementById("photo").files[0];
    if (!ui.chosen) return fail("Choose a category.");
    if (place.length < 2) return fail("Enter the place, such as a street and city.");
    if (description.length < 10) return fail("Describe the incident in at least 10 characters.");
    if (!file) return fail("Add a picture of the incident.");
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        return fail("Enter a valid latitude and longitude.");
    }
    ui.busy = true;
    render();
    compress(file).then(function (photo) {
        const incident = {
            id: uid(),
            userId: ui.user.id,
            reporterName: ui.user.name,
            category: ui.chosen,
            description: description,
            latitude: latitude,
            longitude: longitude,
            placeName: place,
            photo: photo,
            createdAt: new Date().toISOString()
        };
        db.incidents.push(incident);
        const message = "New " + incident.category + " reported at " + incident.placeName;
        db.users.filter(function (user) { return user.id !== ui.user.id; }).forEach(function (user) {
            db.alerts.push({ id: uid(), userId: user.id, incidentId: incident.id, message: message, read: false, createdAt: incident.createdAt });
        });
        ui.chosen = "";
        ui.busy = false;
        ui.screen = "detail";
        ui.detailId = incident.id;
        ui.banner = null;
        saveAll();
        render();
    }).catch(function () {
        ui.busy = false;
        fail("Could not read that picture.");
    });
}

function fail(message) {
    ui.error = message;
    ui.busy = false;
    render();
}

function compress(file) {
    return new Promise(function (resolve, reject) {
        const image = new Image();
        const url = URL.createObjectURL(file);
        image.onload = function () {
            const scale = Math.min(1, 1200 / image.width);
            const canvas = document.createElement("canvas");
            canvas.width = Math.max(1, Math.round(image.width * scale));
            canvas.height = Math.max(1, Math.round(image.height * scale));
            canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
            URL.revokeObjectURL(url);
            resolve(canvas.toDataURL("image/jpeg", 0.72));
        };
        image.onerror = function () {
            URL.revokeObjectURL(url);
            reject(new Error("picture"));
        };
        image.src = url;
    });
}

function start() {
    load();
    render();
}

document.addEventListener("deviceready", start, false);
if (!window.cordova) start();
