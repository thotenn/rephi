import I, { createContext as ae, useState as C, useEffect as H, useContext as ce, useRef as le, useCallback as O, useMemo as ue } from "react";
import { Socket as ie } from "phoenix";
var $ = { exports: {} }, S = {};
/**
 * @license React
 * react-jsx-runtime.production.js
 *
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
var V;
function fe() {
  if (V) return S;
  V = 1;
  var o = Symbol.for("react.transitional.element"), a = Symbol.for("react.fragment");
  function s(t, r, c) {
    var m = null;
    if (c !== void 0 && (m = "" + c), r.key !== void 0 && (m = "" + r.key), "key" in r) {
      c = {};
      for (var i in r)
        i !== "key" && (c[i] = r[i]);
    } else c = r;
    return r = c.ref, {
      $$typeof: o,
      type: t,
      key: m,
      ref: r !== void 0 ? r : null,
      props: c
    };
  }
  return S.Fragment = a, S.jsx = s, S.jsxs = s, S;
}
var g = {};
/**
 * @license React
 * react-jsx-runtime.development.js
 *
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
var X;
function de() {
  return X || (X = 1, process.env.NODE_ENV !== "production" && function() {
    function o(e) {
      if (e == null) return null;
      if (typeof e == "function")
        return e.$$typeof === te ? null : e.displayName || e.name || null;
      if (typeof e == "string") return e;
      switch (e) {
        case E:
          return "Fragment";
        case j:
          return "Profiler";
        case x:
          return "StrictMode";
        case z:
          return "Suspense";
        case ee:
          return "SuspenseList";
        case ne:
          return "Activity";
      }
      if (typeof e == "object")
        switch (typeof e.tag == "number" && console.error(
          "Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."
        ), e.$$typeof) {
          case d:
            return "Portal";
          case U:
            return (e.displayName || "Context") + ".Provider";
          case Q:
            return (e._context.displayName || "Context") + ".Consumer";
          case K:
            var n = e.render;
            return e = e.displayName, e || (e = n.displayName || n.name || "", e = e !== "" ? "ForwardRef(" + e + ")" : "ForwardRef"), e;
          case re:
            return n = e.displayName || null, n !== null ? n : o(e.type) || "Memo";
          case D:
            n = e._payload, e = e._init;
            try {
              return o(e(n));
            } catch {
            }
        }
      return null;
    }
    function a(e) {
      return "" + e;
    }
    function s(e) {
      try {
        a(e);
        var n = !1;
      } catch {
        n = !0;
      }
      if (n) {
        n = console;
        var l = n.error, h = typeof Symbol == "function" && Symbol.toStringTag && e[Symbol.toStringTag] || e.constructor.name || "Object";
        return l.call(
          n,
          "The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",
          h
        ), a(e);
      }
    }
    function t(e) {
      if (e === E) return "<>";
      if (typeof e == "object" && e !== null && e.$$typeof === D)
        return "<...>";
      try {
        var n = o(e);
        return n ? "<" + n + ">" : "<...>";
      } catch {
        return "<...>";
      }
    }
    function r() {
      var e = p.A;
      return e === null ? null : e.getOwner();
    }
    function c() {
      return Error("react-stack-top-frame");
    }
    function m(e) {
      if (M.call(e, "key")) {
        var n = Object.getOwnPropertyDescriptor(e, "key").get;
        if (n && n.isReactWarning) return !1;
      }
      return e.key !== void 0;
    }
    function i(e, n) {
      function l() {
        L || (L = !0, console.error(
          "%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",
          n
        ));
      }
      l.isReactWarning = !0, Object.defineProperty(e, "key", {
        get: l,
        configurable: !0
      });
    }
    function b() {
      var e = o(this.type);
      return W[e] || (W[e] = !0, console.error(
        "Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release."
      )), e = this.props.ref, e !== void 0 ? e : null;
    }
    function v(e, n, l, h, w, _, N, Y) {
      return l = _.ref, e = {
        $$typeof: T,
        type: e,
        key: n,
        props: _,
        _owner: w
      }, (l !== void 0 ? l : null) !== null ? Object.defineProperty(e, "ref", {
        enumerable: !1,
        get: b
      }) : Object.defineProperty(e, "ref", { enumerable: !1, value: null }), e._store = {}, Object.defineProperty(e._store, "validated", {
        configurable: !1,
        enumerable: !1,
        writable: !0,
        value: 0
      }), Object.defineProperty(e, "_debugInfo", {
        configurable: !1,
        enumerable: !1,
        writable: !0,
        value: null
      }), Object.defineProperty(e, "_debugStack", {
        configurable: !1,
        enumerable: !1,
        writable: !0,
        value: N
      }), Object.defineProperty(e, "_debugTask", {
        configurable: !1,
        enumerable: !1,
        writable: !0,
        value: Y
      }), Object.freeze && (Object.freeze(e.props), Object.freeze(e)), e;
    }
    function P(e, n, l, h, w, _, N, Y) {
      var R = n.children;
      if (R !== void 0)
        if (h)
          if (oe(R)) {
            for (h = 0; h < R.length; h++)
              u(R[h]);
            Object.freeze && Object.freeze(R);
          } else
            console.error(
              "React.jsx: Static children should always be an array. You are likely explicitly calling React.jsxs or React.jsxDEV. Use the Babel transform instead."
            );
        else u(R);
      if (M.call(n, "key")) {
        R = o(e);
        var A = Object.keys(n).filter(function(se) {
          return se !== "key";
        });
        h = 0 < A.length ? "{key: someKey, " + A.join(": ..., ") + ": ...}" : "{key: someKey}", q[R + h] || (A = 0 < A.length ? "{" + A.join(": ..., ") + ": ...}" : "{}", console.error(
          `A props object containing a "key" prop is being spread into JSX:
  let props = %s;
  <%s {...props} />
React keys must be passed directly to JSX without using spread:
  let props = %s;
  <%s key={someKey} {...props} />`,
          h,
          R,
          A,
          R
        ), q[R + h] = !0);
      }
      if (R = null, l !== void 0 && (s(l), R = "" + l), m(n) && (s(n.key), R = "" + n.key), "key" in n) {
        l = {};
        for (var F in n)
          F !== "key" && (l[F] = n[F]);
      } else l = n;
      return R && i(
        l,
        typeof e == "function" ? e.displayName || e.name || "Unknown" : e
      ), v(
        e,
        R,
        _,
        w,
        r(),
        l,
        N,
        Y
      );
    }
    function u(e) {
      typeof e == "object" && e !== null && e.$$typeof === T && e._store && (e._store.validated = 1);
    }
    var f = I, T = Symbol.for("react.transitional.element"), d = Symbol.for("react.portal"), E = Symbol.for("react.fragment"), x = Symbol.for("react.strict_mode"), j = Symbol.for("react.profiler"), Q = Symbol.for("react.consumer"), U = Symbol.for("react.context"), K = Symbol.for("react.forward_ref"), z = Symbol.for("react.suspense"), ee = Symbol.for("react.suspense_list"), re = Symbol.for("react.memo"), D = Symbol.for("react.lazy"), ne = Symbol.for("react.activity"), te = Symbol.for("react.client.reference"), p = f.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE, M = Object.prototype.hasOwnProperty, oe = Array.isArray, y = console.createTask ? console.createTask : function() {
      return null;
    };
    f = {
      "react-stack-bottom-frame": function(e) {
        return e();
      }
    };
    var L, W = {}, J = f["react-stack-bottom-frame"].bind(
      f,
      c
    )(), G = y(t(c)), q = {};
    g.Fragment = E, g.jsx = function(e, n, l, h, w) {
      var _ = 1e4 > p.recentlyCreatedOwnerStacks++;
      return P(
        e,
        n,
        l,
        !1,
        h,
        w,
        _ ? Error("react-stack-top-frame") : J,
        _ ? y(t(e)) : G
      );
    }, g.jsxs = function(e, n, l, h, w) {
      var _ = 1e4 > p.recentlyCreatedOwnerStacks++;
      return P(
        e,
        n,
        l,
        !0,
        h,
        w,
        _ ? Error("react-stack-top-frame") : J,
        _ ? y(t(e)) : G
      );
    };
  }()), g;
}
process.env.NODE_ENV === "production" ? $.exports = fe() : $.exports = de();
var k = $.exports;
const Z = ae(void 0), Re = ({
  children: o,
  socketUrl: a = "ws://localhost:4000/socket",
  autoConnect: s = !1,
  token: t
}) => {
  const [r, c] = C(null), [m, i] = C(!1), b = (f, T) => {
    if (r != null && r.isConnected()) {
      console.warn("Socket already connected");
      return;
    }
    const d = new ie(T || a, {
      params: { token: f }
    });
    d.onOpen(() => {
      console.log("Phoenix socket connected"), i(!0);
    }), d.onClose(() => {
      console.log("Phoenix socket disconnected"), i(!1);
    }), d.onError(() => {
      console.error("Phoenix socket error"), i(!1);
    }), d.connect(), c(d);
  }, v = () => {
    r && (r.disconnect(), c(null), i(!1));
  }, P = (f, T = {}) => !r || !m ? (console.warn("Socket not connected"), null) : r.channel(f, T);
  H(() => (s && t && b(t), () => {
    r != null && r.isConnected() && r.disconnect();
  }), []);
  const u = {
    socket: r,
    connected: m,
    connect: b,
    disconnect: v,
    channel: P
  };
  return /* @__PURE__ */ k.jsx(Z.Provider, { value: u, children: o });
}, me = () => {
  const o = ce(Z);
  if (!o)
    throw new Error("usePhoenix must be used within a PhoenixProvider");
  return o;
}, ve = ({
  children: o,
  isAuthenticated: a,
  fallback: s = null,
  redirectTo: t,
  onUnauthorized: r
}) => (I.useEffect(() => {
  a || (t && typeof window < "u" && (window.location.href = t), r == null || r());
}, [a, t, r]), a ? /* @__PURE__ */ k.jsx(k.Fragment, { children: o }) : /* @__PURE__ */ k.jsx(k.Fragment, { children: s })), be = ({
  children: o,
  permissions: a,
  userPermissions: s,
  requireAll: t = !1,
  fallback: r = null,
  onUnauthorized: c
}) => {
  const m = t ? a.every((i) => s.includes(i)) : a.some((i) => s.includes(i));
  return I.useEffect(() => {
    m || c == null || c();
  }, [m, c]), m ? /* @__PURE__ */ k.jsx(k.Fragment, { children: o }) : /* @__PURE__ */ k.jsx(k.Fragment, { children: r });
}, _e = (o, a = {}, s = {}) => {
  const { channel: t, connected: r } = me(), [c, m] = C(null), [i, b] = C(!1), v = le(null), P = O(() => {
    if (!r || v.current) return;
    const d = t(o, a);
    d && (v.current = d, m(d), d.join().receive("ok", () => {
      var E;
      console.log(`Joined channel: ${o}`), b(!0), (E = s.onJoin) == null || E.call(s);
    }).receive("error", (E) => {
      var x;
      console.error(`Failed to join channel: ${o}`, E), (x = s.onError) == null || x.call(s, E);
    }), d.onClose(() => {
      var E;
      console.log(`Channel closed: ${o}`), b(!1), (E = s.onClose) == null || E.call(s);
    }));
  }, [r, o, JSON.stringify(a)]), u = O(() => {
    v.current && (v.current.leave(), v.current = null, m(null), b(!1));
  }, []), f = O((d, E = {}) => !v.current || !i ? (console.warn(`Cannot push to channel ${o}: not joined`), null) : v.current.push(d, E), [i, o]), T = O((d, E) => {
    if (!v.current)
      return console.warn(`Cannot listen to channel ${o}: not created`), () => {
      };
    const x = v.current.on(d, E);
    return () => {
      var j;
      return (j = v.current) == null ? void 0 : j.off(d, x);
    };
  }, [o]);
  return H(() => (r && P(), () => {
    u();
  }), [r, P]), {
    channel: c,
    joined: i,
    join: P,
    leave: u,
    push: f,
    on: T
  };
}, Pe = (o = {}) => {
  const { roles: a = [], permissions: s = [], rolePermissions: t = {} } = o, r = ue(() => {
    const u = new Set(s);
    return a.forEach((f) => {
      (t[f] || []).forEach((d) => u.add(d));
    }), Array.from(u);
  }, [a, s, t]), c = (u) => r.includes(u), m = (u) => u.some((f) => c(f)), i = (u) => u.every((f) => c(f)), b = (u) => a.includes(u);
  return {
    permissions: r,
    roles: a,
    hasPermission: c,
    hasAnyPermission: m,
    hasAllPermissions: i,
    hasRole: b,
    hasAnyRole: (u) => u.some((f) => b(f)),
    hasAllRoles: (u) => u.every((f) => b(f))
  };
}, B = (o, a, s) => o.filter((t) => t.requireAuth && a.length === 0 || t.permissions && t.permissions.length > 0 && !t.permissions.some(
  (c) => a.includes(c)
) || t.roles && t.roles.length > 0 && !t.roles.some(
  (c) => s.includes(c)
) ? !1 : t.children ? B(
  t.children,
  a,
  s
).length > 0 : !0).map((t) => t.children ? {
  ...t,
  children: B(
    t.children,
    a,
    s
  )
} : t), Te = (o, a = {}) => ({
  path: o,
  requireAuth: !0,
  ...a
});
export {
  ve as AuthGuard,
  be as PermissionGuard,
  Re as PhoenixProvider,
  Te as createProtectedRoute,
  B as filterRoutesByPermissions,
  _e as useChannel,
  Pe as usePermissions,
  me as usePhoenix
};
