"use client";

import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import cytoscape, { Core, NodeSingular } from "cytoscape";
import api from "@/lib/api";
import ScoreRing from "@/components/ScoreRing";
import {
  FiZoomIn,
  FiZoomOut,
  FiMaximize2,
  FiRefreshCw,
  FiLayers,
  FiList,
  FiAlertTriangle,
  FiCheckCircle,
  FiShield,
  FiX,
  FiArrowRight,
  FiInfo,
} from "react-icons/fi";

// Try registering fcose layout if available in browser
if (typeof window !== "undefined") {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const fcose = require("cytoscape-fcose");
    cytoscape.use(fcose);
  } catch {
    // Falls back to built-in cose layout
  }
}

interface RiskComponents {
  model_version?: string;
  breach?: number;
  permission_scope?: number;
  password_reuse?: number;
  missing_2fa?: number;
  cascading_impact?: number;
  base_score?: number;
  keystone?: boolean;
  reachable_accounts?: number;
  keystone_floor?: number | null;
  top_paths?: Array<{ account_id: number; probability: number }>;
}

interface GraphNodeData {
  id: string;
  label: string;
  category: string;
  riskScore: number;
  riskLevel: "critical" | "high" | "medium" | "low";
  has2fa: boolean | null;
  twofaMethod?: string | null;
  loginMethod?: string;
  breachCount: number;
  blastRadius: number;
  isKeystone: boolean;
  reachableAccounts: number;
  riskComponents?: RiskComponents;
  topPaths?: Array<{ account_id: number; probability: number }>;
  permissions?: string[];
}

interface GraphEdgeData {
  id: string;
  source: string;
  target: string;
  type: string;
}

interface SPOFItem {
  id: string;
  service_name: string;
  reachable_accounts: number;
  risk_score: number;
  blast_radius: number;
}

interface FixCandidate {
  id: number;
  account_id: number;
  action_type: string;
  description: string;
  priority: number;
  risk_reduction: number;
  status: string;
}

const riskColors: Record<string, string> = {
  critical: "#C8321A",
  high: "#A8660F",
  medium: "#23408E",
  low: "#2E6B4E",
};

const edgeColors: Record<string, string> = {
  sso: "#6B3A6E",
  recovery_email: "#A8660F",
  recovery_phone: "#A8660F",
  password_reuse: "#C8321A",
  device_trust: "#5B544A",
  data_sharing: "#1F6E78",
};

const CONNECTION_CHIPS = [
  { label: "All", value: "all" },
  { label: "Password Reuse", value: "password_reuse" },
  { label: "Recovery", value: "recovery_email" },
  { label: "SSO", value: "sso" },
  { label: "Data Sharing", value: "data_sharing" },
];

export default function RiskGraphPage() {
  const containerRef = useRef<HTMLDivElement>(null);
  const cyRef = useRef<Core | null>(null);

  const [nodes, setNodes] = useState<GraphNodeData[]>([]);
  const [edges, setEdges] = useState<GraphEdgeData[]>([]);
  const [spofs, setSpofs] = useState<SPOFItem[]>([]);
  const [privacyScore, setPrivacyScore] = useState<number>(100);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Interaction & UI State
  const [selectedNode, setSelectedNode] = useState<GraphNodeData | null>(null);
  const [edgeFilter, setEdgeFilter] = useState<string>("all");
  const [categoryFilter, setCategoryFilter] = useState<string>("All");
  const [heatmapMode, setHeatmapMode] = useState<boolean>(false);
  const [viewMode, setViewMode] = useState<"graph" | "table">("graph");
  const [allFixes, setAllFixes] = useState<FixCandidate[]>([]);
  const [simulatedFixIds, setSimulatedFixIds] = useState<number[]>([]);
  const [previewImprovement, setPreviewImprovement] = useState<number>(0);

  // Check if dataset contains seeded demo accounts
  const isDemoData = useMemo(() => {
    return nodes.some(
      (n) =>
        n.label.toLowerCase().includes("demo") ||
        n.label.toLowerCase().includes("canva") ||
        n.label.toLowerCase().includes("keystone")
    );
  }, [nodes]);

  // Load Graph and Fixes
  const loadGraphData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [graphRes, fixesRes] = await Promise.allSettled([
        api.get("/graph/"),
        api.get("/dashboard/fixes"),
      ]);

      if (graphRes.status === "fulfilled") {
        const data = graphRes.value.data;
        setNodes(data.nodes || []);
        setEdges(data.edges || []);
        setSpofs(data.spofs || []);
        if (data.privacyScore !== undefined) {
          setPrivacyScore(data.privacyScore);
        }
      } else {
        throw new Error("Failed to load graph data");
      }

      if (fixesRes.status === "fulfilled" && Array.isArray(fixesRes.value.data)) {
        setAllFixes(fixesRes.value.data);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error loading risk graph");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadGraphData();
  }, [loadGraphData]);

  // Categories for filter
  const categories = useMemo(() => {
    return ["All", ...Array.from(new Set(nodes.map((n) => n.category))).sort()];
  }, [nodes]);

  // Initialize Cytoscape
  useEffect(() => {
    if (!containerRef.current || viewMode !== "graph" || nodes.length === 0) return;

    // Filter elements
    const visibleNodes = nodes.filter((n) => {
      if (categoryFilter !== "All" && n.category !== categoryFilter) return false;
      return true;
    });
    const visibleNodeIds = new Set(visibleNodes.map((n) => n.id));

    const visibleEdges = edges.filter((e) => {
      if (!visibleNodeIds.has(e.source) || !visibleNodeIds.has(e.target)) return false;
      if (edgeFilter !== "all") {
        if (edgeFilter === "recovery_email" && !e.type.startsWith("recovery")) return false;
        if (edgeFilter !== "recovery_email" && e.type !== edgeFilter) return false;
      }
      return true;
    });

    const elements = [
      ...visibleNodes.map((n) => {
        const badge = n.riskLevel === "critical" ? " ‼" : n.riskLevel === "high" || n.riskLevel === "medium" ? " !" : " ✓";
        const baseSize = 34;
        const radiusScale = Math.min(26, (n.blastRadius / 100) * 26);
        const nodeSize = baseSize + radiusScale;

        return {
          data: {
            id: n.id,
            label: `${n.label}${badge}`,
            rawLabel: n.label,
            badge,
            color: heatmapMode ? (n.riskScore >= 50 ? "#C8321A" : "#2E6B4E") : riskColors[n.riskLevel] || "#2E6B4E",
            size: nodeSize,
            riskScore: n.riskScore,
            isKeystone: n.isKeystone,
            blastRadius: n.blastRadius,
            nodeData: n,
          },
        };
      }),
      ...visibleEdges.map((e) => ({
        data: {
          id: e.id,
          source: e.source,
          target: e.target,
          type: e.type,
          color: edgeColors[e.type] || "#B8AE9A",
          lineStyle: e.type === "password_reuse" ? "dashed" : e.type.includes("data") ? "dotted" : "solid",
        },
      })),
    ];

    if (cyRef.current) {
      cyRef.current.destroy();
    }

    const cy = cytoscape({
      container: containerRef.current,
      elements,
      style: [
        {
          selector: "node",
          style: {
            "background-color": "#FBF9F4",
            "border-width": 3,
            "border-color": "data(color)",
            width: "data(size)",
            height: "data(size)",
            label: "data(label)",
            "font-size": "11px",
            "font-family": "ui-sans-serif, system-ui, sans-serif",
            "font-weight": 600,
            color: "#17150F",
            "text-valign": "bottom",
            "text-margin-y": 6,
            "text-background-opacity": 0.85,
            "text-background-color": "#F2EEE5",
            "text-background-padding": "2px",
            "text-background-shape": "roundrectangle",
            "transition-property": "opacity, border-color, border-width, width, height",
            "transition-duration": 0.25,
          },
        },
        {
          selector: "node[?isKeystone]",
          style: {
            "border-width": 4.5,
            "border-style": "double",
          },
        },
        {
          selector: "edge",
          style: {
            width: 2,
            "line-color": "data(color)",
            "line-style": "data(lineStyle)" as cytoscape.Css.LineStyle,
            "curve-style": "bezier",
            "target-arrow-shape": "triangle",
            "target-arrow-color": "data(color)",
            "arrow-scale": 0.8,
            opacity: 0.7,
            "transition-property": "opacity, line-color, width",
            "transition-duration": 0.25,
          },
        },
        {
          selector: ".highlighted",
          style: {
            opacity: 1,
            "border-width": 4.5,
            "z-index": 999,
          },
        },
        {
          selector: ".dimmed",
          style: {
            opacity: 0.15,
          },
        },
        {
          selector: ":selected",
          style: {
            "border-color": "#17150F",
            "border-width": 4.5,
          },
        },
      ],
      layout: {
        name: "cose",
        animate: true,
        animationDuration: 600,
        nodeRepulsion: () => 8000,
        idealEdgeLength: () => 100,
        edgeElasticity: () => 100,
        gravity: 0.25,
      },
      minZoom: 0.3,
      maxZoom: 2.5,
      wheelSensitivity: 0.2,
    });

    // Node Click -> Open Drawer
    cy.on("tap", "node", (evt) => {
      const node = evt.target as NodeSingular;
      const nodeData = node.data("nodeData") as GraphNodeData;
      setSelectedNode(nodeData);
    });

    // Background Click -> Deselect
    cy.on("tap", (evt) => {
      if (evt.target === cy) {
        setSelectedNode(null);
        cy.elements().removeClass("highlighted dimmed");
      }
    });

    // Hover -> Highlight blast radius (reachable targets) and dim rest
    cy.on("mouseover", "node", (evt) => {
      const node = evt.target as NodeSingular;
      const reachable = node.outgoers();
      const connectedEdges = node.connectedEdges();

      cy.elements().addClass("dimmed");
      node.removeClass("dimmed").addClass("highlighted");
      reachable.removeClass("dimmed").addClass("highlighted");
      connectedEdges.removeClass("dimmed").addClass("highlighted");
    });

    cy.on("mouseout", "node", () => {
      cy.elements().removeClass("highlighted dimmed");
    });

    cyRef.current = cy;

    return () => {
      cy.destroy();
    };
  }, [nodes, edges, categoryFilter, edgeFilter, heatmapMode, viewMode]);

  // Handle Graph Zoom / Pan Controls
  const handleZoomIn = () => cyRef.current?.zoom(cyRef.current.zoom() * 1.25);
  const handleZoomOut = () => cyRef.current?.zoom(cyRef.current.zoom() * 0.8);
  const handleFit = () => cyRef.current?.fit(undefined, 30);
  const handleReset = () => {
    cyRef.current?.reset();
    cyRef.current?.fit(undefined, 30);
  };

  // Toggle Fix Simulation Preview
  const handleToggleFixSimulation = async (fix: FixCandidate) => {
    const isTicked = simulatedFixIds.includes(fix.id);
    let updatedFixIds: number[];
    if (isTicked) {
      updatedFixIds = simulatedFixIds.filter((id) => id !== fix.id);
    } else {
      updatedFixIds = [...simulatedFixIds, fix.id];
    }
    setSimulatedFixIds(updatedFixIds);

    // Calculate simulated preview score gain
    const totalReduction = allFixes
      .filter((f) => updatedFixIds.includes(f.id))
      .reduce((acc, f) => acc + (f.risk_reduction || 0), 0);
    setPreviewImprovement(Math.round(totalReduction));
  };

  // Complete a fix directly from the drawer
  const handleCompleteFix = async (fixId: number) => {
    try {
      await api.patch(`/dashboard/fixes/${fixId}/complete`);
      // Reload graph and fixes with real updated state
      await loadGraphData();
      if (selectedNode) {
        // Refresh selected node from updated state
        setSelectedNode(null);
      }
    } catch (e) {
      console.error(e);
    }
  };

  // Drawer Candidate Fixes for selected account
  const nodeCandidateFixes = useMemo(() => {
    if (!selectedNode) return [];
    return allFixes.filter((f) => String(f.account_id) === String(selectedNode.id)).slice(0, 3);
  }, [selectedNode, allFixes]);

  return (
    <div className="space-y-6">
      {/* Header with Title and Mode Switchers */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-3">
            <p className="eyebrow">Audit &middot; Exposure Topology</p>
            {isDemoData && (
              <span className="px-2 py-0.5 bg-[#C8321A]/10 text-[#C8321A] border border-[#C8321A]/30 text-[10px] font-mono uppercase tracking-widest rounded-sm">
                DEMO DATA
              </span>
            )}
          </div>
          <h1 className="page-title mt-1">Risk Graph</h1>
          <p className="text-[#5B544A] text-sm mt-1">
            Real-time cascading risk engine and single-point-of-failure topology
          </p>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => setHeatmapMode(!heatmapMode)}
            className={`px-3 py-2 rounded-sm text-xs font-medium flex items-center gap-2 transition-all ${
              heatmapMode
                ? "bg-[#C8321A] text-white"
                : "bg-[#FBF9F4] text-[#5B544A] border border-[#DCD4C4] hover:border-[#17150F]"
            }`}
            title="Toggle Heatmap Color Mode"
            aria-label="Toggle Heatmap"
          >
            <FiLayers className="w-4 h-4" />
            <span>Heatmap</span>
          </button>

          <div className="border border-[#DCD4C4] rounded-sm bg-[#FBF9F4] p-0.5 flex">
            <button
              onClick={() => setViewMode("graph")}
              className={`px-3 py-1.5 rounded-sm text-xs font-medium transition-all ${
                viewMode === "graph" ? "bg-[#17150F] text-white" : "text-[#5B544A] hover:text-[#17150F]"
              }`}
              aria-label="Switch to Graph View"
            >
              Graph View
            </button>
            <button
              onClick={() => setViewMode("table")}
              className={`px-3 py-1.5 rounded-sm text-xs font-medium flex items-center gap-1.5 transition-all ${
                viewMode === "table" ? "bg-[#17150F] text-white" : "text-[#5B544A] hover:text-[#17150F]"
              }`}
              aria-label="Switch to Accessible Table View"
            >
              <FiList className="w-3.5 h-3.5" />
              <span>Table</span>
            </button>
          </div>
        </div>
      </div>

      {/* SPOF Banner: Single Points of Failure */}
      {spofs.length > 0 && (
        <div className="bg-[#C8321A]/10 border-2 border-[#C8321A] rounded-sm p-4 animate-slide-up">
          <div className="flex items-start gap-3">
            <div className="p-2 bg-[#C8321A] text-white rounded-sm mt-0.5">
              <FiAlertTriangle className="w-5 h-5 animate-pulse" />
            </div>
            <div className="flex-1">
              <h2 className="text-sm font-bold text-[#C8321A] uppercase tracking-wide">
                Single Point of Failure Alert ({spofs.length} Keystone Accounts Detected)
              </h2>
              <p className="text-xs text-[#5B544A] mt-1">
                If any of these keystone hubs are breached, cascading reachability threatens connected accounts:
              </p>
              <div className="flex flex-wrap gap-3 mt-3">
                {spofs.map((s) => (
                  <div
                    key={s.id}
                    onClick={() => {
                      const matched = nodes.find((n) => n.id === s.id);
                      if (matched) setSelectedNode(matched);
                    }}
                    className="cursor-pointer bg-[#FBF9F4] border border-[#C8321A]/40 hover:border-[#C8321A] px-3 py-2 rounded-sm text-xs transition-all shadow-xs"
                  >
                    <span className="font-bold text-[#17150F]">{s.service_name}</span>
                    <span className="text-[#8A8274] ml-2">
                      &rarr; Controls <strong>{s.reachable_accounts}</strong> downstream accounts
                    </span>
                    <span className="ml-2 font-mono text-[#C8321A] font-semibold">
                      (Risk {s.risk_score.toFixed(0)})
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 bg-[#FBF9F4] border border-[#DCD4C4] p-3 rounded-sm">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs text-[#8A8274] font-medium mr-1">Connection:</span>
          {CONNECTION_CHIPS.map((chip) => (
            <button
              key={chip.value}
              onClick={() => setEdgeFilter(chip.value)}
              className={`px-3 py-1 rounded-sm text-xs font-medium transition-all ${
                edgeFilter === chip.value
                  ? "bg-[#17150F] text-white"
                  : "bg-white text-[#5B544A] border border-[#DCD4C4] hover:border-[#17150F]"
              }`}
            >
              {chip.label}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <span className="text-xs text-[#8A8274] font-medium">Category:</span>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-1 bg-white border border-[#DCD4C4] rounded-sm text-xs text-[#17150F] focus:outline-none focus:border-[#17150F]"
          >
            {categories.map((c) => (
              <option key={c} value={c}>
                {c === "All" ? "All Categories" : c}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Main Content: Graph Canvas OR Accessible Table */}
      {viewMode === "graph" ? (
        <div className="relative bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm overflow-hidden min-h-[560px]">
          {/* Cytoscape Container */}
          <div ref={containerRef} className="w-full h-[560px]" tabIndex={0} aria-label="Risk Graph Visualizer" />

          {/* Floating Graph Toolbar */}
          <div className="absolute top-4 right-4 flex flex-col gap-1.5 bg-[#FBF9F4]/90 backdrop-blur-xs border border-[#DCD4C4] p-1.5 rounded-sm shadow-sm z-10">
            <button
              onClick={handleZoomIn}
              className="p-2 hover:bg-[#F2EEE5] text-[#17150F] rounded-sm transition-all"
              title="Zoom In"
              aria-label="Zoom In"
            >
              <FiZoomIn className="w-4 h-4" />
            </button>
            <button
              onClick={handleZoomOut}
              className="p-2 hover:bg-[#F2EEE5] text-[#17150F] rounded-sm transition-all"
              title="Zoom Out"
              aria-label="Zoom Out"
            >
              <FiZoomOut className="w-4 h-4" />
            </button>
            <button
              onClick={handleFit}
              className="p-2 hover:bg-[#F2EEE5] text-[#17150F] rounded-sm transition-all"
              title="Fit to Screen"
              aria-label="Fit View"
            >
              <FiMaximize2 className="w-4 h-4" />
            </button>
            <button
              onClick={handleReset}
              className="p-2 hover:bg-[#F2EEE5] text-[#17150F] rounded-sm transition-all"
              title="Reset Layout"
              aria-label="Reset View"
            >
              <FiRefreshCw className="w-4 h-4" />
            </button>
          </div>

          {/* Interactive Legend Banner */}
          <div className="absolute bottom-4 left-4 bg-[#FBF9F4]/95 backdrop-blur-xs border border-[#DCD4C4] p-3 rounded-sm shadow-sm flex flex-wrap gap-4 text-xs z-10 max-w-xl">
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-full bg-[#C8321A]" />
              <span className="text-[#17150F]">Critical (&ge;75)</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-full bg-[#A8660F]" />
              <span className="text-[#17150F]">High (50-74)</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-full bg-[#23408E]" />
              <span className="text-[#17150F]">Medium (25-49)</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-full bg-[#2E6B4E]" />
              <span className="text-[#17150F]">Low (&lt;25)</span>
            </div>
            <div className="border-l border-[#DCD4C4] pl-3 flex items-center gap-3">
              <span className="text-[#5B544A]">Node Size = Blast Radius</span>
              <span className="text-[#5B544A]">Double Border = Keystone Hub</span>
            </div>
          </div>

          {/* Empty / Error state overlays */}
          {loading && (
            <div className="absolute inset-0 bg-[#F2EEE5]/80 flex items-center justify-center z-20">
              <div className="flex flex-col items-center gap-2">
                <div className="w-8 h-8 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
                <p className="text-xs text-[#5B544A] font-medium">Computing topological blast radius...</p>
              </div>
            </div>
          )}

          {!loading && nodes.length === 0 && (
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center p-6 z-10">
              <FiShield className="w-12 h-12 text-[#8A8274] mb-3" />
              <h3 className="section-title text-[#17150F]">No Accounts in Graph</h3>
              <p className="text-sm text-[#5B544A] max-w-sm mt-1">
                Add accounts and connections via Smart Import or Accounts inventory to generate your exposure topology.
              </p>
            </div>
          )}

          {error && (
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center p-6 bg-[#F2EEE5] z-10">
              <FiAlertTriangle className="w-10 h-10 text-[#C8321A] mb-2" />
              <p className="text-sm text-[#C8321A] font-medium">{error}</p>
              <button
                onClick={loadGraphData}
                className="mt-3 px-4 py-2 bg-[#17150F] text-white text-xs rounded-sm"
              >
                Retry
              </button>
            </div>
          )}
        </div>
      ) : (
        /* Accessible Sortable Table View */
        <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm overflow-x-auto">
          <table className="w-full text-left text-xs" aria-label="Account Risk and Exposure Table">
            <thead className="bg-[#F2EEE5] border-b border-[#DCD4C4] text-[#8A8274] uppercase tracking-wider font-mono">
              <tr>
                <th className="p-3">Service Name</th>
                <th className="p-3">Category</th>
                <th className="p-3">Risk Level</th>
                <th className="p-3">Risk Score</th>
                <th className="p-3">Blast Radius</th>
                <th className="p-3">Reachable Nodes</th>
                <th className="p-3">2FA Status</th>
                <th className="p-3">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#DCD4C4]">
              {nodes.map((n) => (
                <tr
                  key={n.id}
                  onClick={() => setSelectedNode(n)}
                  className="hover:bg-[#F2EEE5]/60 cursor-pointer transition-colors"
                >
                  <td className="p-3 font-semibold text-[#17150F] flex items-center gap-2">
                    <span>{n.label}</span>
                    {n.isKeystone && (
                      <span className="px-1.5 py-0.5 bg-[#C8321A]/10 text-[#C8321A] border border-[#C8321A]/30 text-[9px] font-mono rounded">
                        KEYSTONE
                      </span>
                    )}
                  </td>
                  <td className="p-3 capitalize text-[#5B544A]">{n.category}</td>
                  <td className="p-3">
                    <span
                      className="px-2 py-0.5 rounded text-[10px] font-bold uppercase"
                      style={{
                        backgroundColor: `${riskColors[n.riskLevel]}15`,
                        color: riskColors[n.riskLevel],
                      }}
                    >
                      {n.riskLevel}
                    </span>
                  </td>
                  <td className="p-3 font-mono font-bold" style={{ color: riskColors[n.riskLevel] }}>
                    {n.riskScore.toFixed(0)}
                  </td>
                  <td className="p-3 font-mono">{n.blastRadius.toFixed(1)}%</td>
                  <td className="p-3 font-mono">{n.reachableAccounts}</td>
                  <td className="p-3">
                    {n.has2fa ? (
                      <span className="text-[#2E6B4E] font-medium flex items-center gap-1">
                        <FiCheckCircle className="w-3.5 h-3.5" /> {n.twofaMethod || "Active"}
                      </span>
                    ) : (
                      <span className="text-[#C8321A] font-medium flex items-center gap-1">
                        <FiAlertTriangle className="w-3.5 h-3.5" /> Missing
                      </span>
                    )}
                  </td>
                  <td className="p-3">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedNode(n);
                      }}
                      className="px-2.5 py-1 bg-[#17150F] text-white text-[11px] rounded-sm hover:bg-[#5B544A] transition-all"
                    >
                      Inspect
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Fix Preview Simulation & Impact Bar */}
      <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-5">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[#DCD4C4] pb-4">
          <div>
            <h2 className="section-title text-base font-bold text-[#17150F]">
              Deterministic Fix Simulation &amp; Preview
            </h2>
            <p className="text-xs text-[#5B544A] mt-0.5">
              Select candidate remediation actions to calculate exact real-time network privacy score gain:
            </p>
          </div>
          <div className="flex items-center gap-4 bg-[#F2EEE5] p-3 rounded-sm border border-[#DCD4C4]">
            <div>
              <p className="text-[10px] text-[#8A8274] uppercase tracking-wider font-mono">Current Score</p>
              <p className="text-xl font-bold font-mono text-[#17150F]">{privacyScore}</p>
            </div>
            <FiArrowRight className="w-4 h-4 text-[#8A8274]" />
            <div>
              <p className="text-[10px] text-[#8A8274] uppercase tracking-wider font-mono">Simulated Score</p>
              <p className="text-xl font-bold font-mono text-[#2E6B4E]">
                {Math.min(100, privacyScore + previewImprovement)}
                {previewImprovement > 0 && <span className="text-xs ml-1">(+{previewImprovement})</span>}
              </p>
            </div>
          </div>
        </div>

        {/* Candidate Actions Checklist */}
        <div className="mt-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {allFixes.slice(0, 6).map((fix) => {
            const isChecked = simulatedFixIds.includes(fix.id);
            return (
              <label
                key={fix.id}
                className={`p-3 rounded-sm border cursor-pointer transition-all flex items-start gap-3 ${
                  isChecked
                    ? "bg-[#2E6B4E]/5 border-[#2E6B4E]"
                    : "bg-white border-[#DCD4C4] hover:border-[#17150F]"
                }`}
              >
                <input
                  type="checkbox"
                  checked={isChecked}
                  onChange={() => handleToggleFixSimulation(fix)}
                  className="mt-1 accent-[#2E6B4E] cursor-pointer"
                />
                <div className="flex-1 text-xs">
                  <p className="font-semibold text-[#17150F]">{fix.description}</p>
                  <p className="text-[#8A8274] mt-1 flex items-center gap-2 font-mono">
                    <span className="text-[#2E6B4E] font-bold">+{fix.risk_reduction.toFixed(0)} pts</span>
                    <span>&middot;</span>
                    <span>Priority {fix.priority}</span>
                  </p>
                </div>
              </label>
            );
          })}
        </div>
      </div>

      {/* Drawer: Detailed Node Inspection & Risk Breakdown */}
      {selectedNode && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="drawer-title"
          className="fixed inset-y-0 right-0 w-full max-w-md bg-[#FBF9F4] border-l border-[#DCD4C4] shadow-2xl z-50 flex flex-col animate-slide-up"
        >
          {/* Drawer Header */}
          <div className="p-5 border-b border-[#DCD4C4] flex items-center justify-between bg-[#F2EEE5]">
            <div>
              <p className="eyebrow">{selectedNode.category} &middot; Account Inspection</p>
              <h2 id="drawer-title" className="text-xl font-bold text-[#17150F] mt-0.5">
                {selectedNode.label}
              </h2>
            </div>
            <button
              onClick={() => setSelectedNode(null)}
              className="p-2 hover:bg-[#DCD4C4] text-[#17150F] rounded-sm transition-colors"
              aria-label="Close Drawer"
            >
              <FiX className="w-5 h-5" />
            </button>
          </div>

          {/* Drawer Body */}
          <div className="flex-1 overflow-y-auto p-5 space-y-6">
            {/* Score Ring Gauge */}
            <div className="flex flex-col items-center justify-center p-4 bg-white border border-[#DCD4C4] rounded-sm">
              <ScoreRing score={Math.round(selectedNode.riskScore)} size={150} strokeWidth={6} />
              <p className="text-xs text-[#5B544A] mt-2 font-medium">
                Risk Classification:{" "}
                <strong
                  className="uppercase font-mono"
                  style={{ color: riskColors[selectedNode.riskLevel] }}
                >
                  {selectedNode.riskLevel}
                </strong>
              </p>
            </div>

            {/* Plain-English Explanation: "Why this score?" */}
            <div className="p-4 bg-[#F2EEE5] rounded-sm border border-[#DCD4C4]">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#17150F] flex items-center gap-1.5">
                <FiInfo className="w-3.5 h-3.5 text-[#23408E]" />
                Why this score?
              </h3>
              <p className="text-xs text-[#5B544A] mt-2 leading-relaxed">
                {selectedNode.isKeystone
                  ? `This account acts as a critical Single Point of Failure (keystone). Compromising ${selectedNode.label} allows pivoting across ${selectedNode.reachableAccounts} connected accounts in the network.`
                  : selectedNode.riskScore >= 50
                  ? `Elevated risk due to missing multi-factor authentication combined with exposure in ${selectedNode.breachCount} data breaches.`
                  : `Well-managed account with low cascading exposure and bounded blast radius.`}
              </p>
            </div>

            {/* Component Breakdown Bars */}
            {selectedNode.riskComponents && (
              <div className="space-y-3">
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#17150F]">
                  Deterministic Factor Weights (0-100)
                </h3>

                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-[#5B544A]">Breach History (30%)</span>
                    <span className="font-mono font-bold">
                      {selectedNode.riskComponents.breach?.toFixed(0)}
                    </span>
                  </div>
                  <div className="w-full h-1.5 bg-[#DCD4C4] rounded-full overflow-hidden">
                    <div
                      className="h-full bg-[#C8321A]"
                      style={{ width: `${selectedNode.riskComponents.breach || 0}%` }}
                    />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-[#5B544A]">Permission Scope (20%)</span>
                    <span className="font-mono font-bold">
                      {selectedNode.riskComponents.permission_scope?.toFixed(0)}
                    </span>
                  </div>
                  <div className="w-full h-1.5 bg-[#DCD4C4] rounded-full overflow-hidden">
                    <div
                      className="h-full bg-[#A8660F]"
                      style={{ width: `${selectedNode.riskComponents.permission_scope || 0}%` }}
                    />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-[#5B544A]">Password Reuse (20%)</span>
                    <span className="font-mono font-bold">
                      {selectedNode.riskComponents.password_reuse?.toFixed(0)}
                    </span>
                  </div>
                  <div className="w-full h-1.5 bg-[#DCD4C4] rounded-full overflow-hidden">
                    <div
                      className="h-full bg-[#C8321A]"
                      style={{ width: `${selectedNode.riskComponents.password_reuse || 0}%` }}
                    />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-[#5B544A]">Missing 2FA (15%)</span>
                    <span className="font-mono font-bold">
                      {selectedNode.riskComponents.missing_2fa?.toFixed(0)}
                    </span>
                  </div>
                  <div className="w-full h-1.5 bg-[#DCD4C4] rounded-full overflow-hidden">
                    <div
                      className="h-full bg-[#A8660F]"
                      style={{ width: `${selectedNode.riskComponents.missing_2fa || 0}%` }}
                    />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-[#5B544A]">Cascading Impact / Blast Radius (15%)</span>
                    <span className="font-mono font-bold">
                      {selectedNode.riskComponents.cascading_impact?.toFixed(0)}
                    </span>
                  </div>
                  <div className="w-full h-1.5 bg-[#DCD4C4] rounded-full overflow-hidden">
                    <div
                      className="h-full bg-[#6B3A6E]"
                      style={{ width: `${selectedNode.riskComponents.cascading_impact || 0}%` }}
                    />
                  </div>
                </div>
              </div>
            )}

            {/* Attack Paths */}
            {selectedNode.topPaths && selectedNode.topPaths.length > 0 && (
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#17150F] mb-2">
                  Top Reachable Exposure Chains
                </h3>
                <div className="space-y-1.5">
                  {selectedNode.topPaths.map((p, idx) => (
                    <div
                      key={idx}
                      className="p-2 bg-white border border-[#DCD4C4] rounded-sm text-xs flex justify-between items-center"
                    >
                      <span className="text-[#5B544A]">Account #{p.account_id}</span>
                      <span className="font-mono font-semibold text-[#17150F]">
                        {(p.probability * 100).toFixed(1)}% reachability
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Top 3 Candidate Fixes with Real Before / After */}
            <div>
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#17150F] mb-2">
                Recommended Remediation Actions
              </h3>
              {nodeCandidateFixes.length > 0 ? (
                <div className="space-y-2">
                  {nodeCandidateFixes.map((f) => (
                    <div
                      key={f.id}
                      className="p-3 bg-white border border-[#DCD4C4] rounded-sm text-xs space-y-2"
                    >
                      <div className="flex justify-between items-start gap-2">
                        <span className="font-semibold text-[#17150F]">{f.description}</span>
                        <span className="font-mono text-[#2E6B4E] font-bold">
                          +{f.risk_reduction.toFixed(0)} pts
                        </span>
                      </div>
                      <div className="flex justify-between items-center pt-2 border-t border-[#DCD4C4]">
                        <span className="text-[#8A8274] font-mono">Priority: {f.priority}</span>
                        <button
                          onClick={() => handleCompleteFix(f.id)}
                          className="px-3 py-1 bg-[#17150F] hover:bg-[#2E6B4E] text-white rounded-sm font-medium transition-all"
                        >
                          Confirm Fix
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-[#8A8274] italic">
                  No pending fixes for this account. Current security controls verified.
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
