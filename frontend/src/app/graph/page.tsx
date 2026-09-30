"use client";

import { useEffect, useState, useRef, useCallback } from "react";
import api from "@/lib/api";

interface GraphNode {
  id: string;
  label: string;
  category: string;
  riskScore: number;
  riskLevel: string;
  has2fa: boolean;
  loginMethod: string;
  breachCount: number;
  x?: number;
  y?: number;
  vx?: number;
  vy?: number;
}

interface GraphEdge {
  id: string;
  source: string;
  target: string;
  type: string;
}

interface AttackResult {
  entryPoint: string;
  totalCompromised: number;
  totalAccounts: number;
  attackPath: Array<{ step: number; accountId: number; serviceName: string; riskScore: number }>;
  financialAccountsAtRisk: number;
  compromisedIds: string[];
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
  password_reuse: "#C8321A",
  data_sharing: "#1F6E78",
};

const connectionTypes = ["All", "SSO", "Recovery", "Password Reuse", "Data Sharing"];
const connectionTypeMap: Record<string, string> = {
  "SSO": "sso",
  "Recovery": "recovery_email",
  "Password Reuse": "password_reuse",
  "Data Sharing": "data_sharing",
};

export default function GraphPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const minimapRef = useRef<HTMLCanvasElement>(null);
  const [nodes, setNodes] = useState<GraphNode[]>([]);
  const [edges, setEdges] = useState<GraphEdge[]>([]);
  const [selectedNode, setSelectedNode] = useState<GraphNode | null>(null);
  const [attackResult, setAttackResult] = useState<AttackResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [edgeFilter, setEdgeFilter] = useState("All");
  const [categoryFilter, setCategoryFilter] = useState("All");
  const animRef = useRef<number>(0);
  const dragRef = useRef<{ node: GraphNode | null; offsetX: number; offsetY: number }>({ node: null, offsetX: 0, offsetY: 0 });

  const categories = ["All", ...Array.from(new Set(nodes.map((n) => n.category))).sort()];

  const filteredEdges = edges.filter((e) => {
    if (edgeFilter !== "All") {
      const mapped = connectionTypeMap[edgeFilter];
      if (mapped && e.type !== mapped) return false;
    }
    return true;
  });

  const connectedNodeIds = new Set<string>();
  if (categoryFilter === "All" && edgeFilter === "All") {
    nodes.forEach((n) => connectedNodeIds.add(n.id));
  } else {
    filteredEdges.forEach((e) => {
      connectedNodeIds.add(e.source);
      connectedNodeIds.add(e.target);
    });
    if (categoryFilter === "All") {
      nodes.forEach((n) => connectedNodeIds.add(n.id));
    }
  }

  const filteredNodes = nodes.filter((n) => {
    if (categoryFilter !== "All" && n.category !== categoryFilter) return false;
    if (edgeFilter !== "All" && !connectedNodeIds.has(n.id)) return false;
    return true;
  });

  useEffect(() => {
    api.get("/graph/").then((r) => {
      const { nodes: n, edges: e } = r.data;
      const width = 800;
      const height = 500;
      n.forEach((node: GraphNode, i: number) => {
        const angle = (2 * Math.PI * i) / n.length;
        const radius = Math.min(width, height) * 0.35;
        node.x = width / 2 + radius * Math.cos(angle);
        node.y = height / 2 + radius * Math.sin(angle);
        node.vx = 0;
        node.vy = 0;
      });
      setNodes(n);
      setEdges(e);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const simulate = useCallback(() => {
    if (nodes.length === 0) return;

    const width = 800;
    const height = 500;

    nodes.forEach((node) => {
      let fx = 0, fy = 0;
      nodes.forEach((other) => {
        if (node.id === other.id) return;
        const dx = node.x! - other.x!;
        const dy = node.y! - other.y!;
        const dist = Math.max(Math.sqrt(dx * dx + dy * dy), 1);
        const force = 5000 / (dist * dist);
        fx += (dx / dist) * force;
        fy += (dy / dist) * force;
      });

      edges.forEach((edge) => {
        let other: GraphNode | undefined;
        if (edge.source === node.id) other = nodes.find((n) => n.id === edge.target);
        else if (edge.target === node.id) other = nodes.find((n) => n.id === edge.source);
        if (other) {
          const dx = other.x! - node.x!;
          const dy = other.y! - node.y!;
          const dist = Math.sqrt(dx * dx + dy * dy);
          const force = (dist - 120) * 0.05;
          fx += (dx / dist) * force;
          fy += (dy / dist) * force;
        }
      });

      const cx = width / 2 - node.x!;
      const cy = height / 2 - node.y!;
      fx += cx * 0.002;
      fy += cy * 0.002;

      if (!dragRef.current.node || dragRef.current.node.id !== node.id) {
        node.vx = (node.vx! + fx) * 0.8;
        node.vy = (node.vy! + fy) * 0.8;
        node.x! += node.vx!;
        node.y! += node.vy!;
        node.x = Math.max(30, Math.min(width - 30, node.x!));
        node.y = Math.max(30, Math.min(height - 30, node.y!));
      }
    });

    setNodes([...nodes]);
  }, [nodes, edges]);

  useEffect(() => {
    const tick = () => {
      simulate();
      animRef.current = requestAnimationFrame(tick);
    };
    animRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(animRef.current);
  }, [simulate]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.clearRect(0, 0, 800, 500);

    const visibleNodeIds = new Set(filteredNodes.map((n) => n.id));

    filteredEdges.forEach((edge) => {
      const source = nodes.find((n) => n.id === edge.source);
      const target = nodes.find((n) => n.id === edge.target);
      if (!source || !target) return;
      if (!visibleNodeIds.has(source.id) || !visibleNodeIds.has(target.id)) return;

      const isAttacked = attackResult && attackResult.compromisedIds.includes(source.id) && attackResult.compromisedIds.includes(target.id);

      ctx.beginPath();
      ctx.moveTo(source.x!, source.y!);
      ctx.lineTo(target.x!, target.y!);
      ctx.strokeStyle = isAttacked ? "#C8321A" : (edgeColors[edge.type] || "#B8AE9A");
      ctx.lineWidth = isAttacked ? 3 : 1.5;
      ctx.globalAlpha = isAttacked ? 1 : 0.5;
      ctx.stroke();
      ctx.globalAlpha = 1;
    });

    const font = getComputedStyle(document.body).fontFamily;
    filteredNodes.forEach((node) => {
      const isCompromised = attackResult?.compromisedIds.includes(node.id);
      const isSelected = selectedNode?.id === node.id;
      const radius = isSelected ? 20 : 16;
      const ring = isCompromised ? "#C8321A" : riskColors[node.riskLevel] || "#B8AE9A";

      if (isCompromised) {
        ctx.beginPath();
        ctx.arc(node.x!, node.y!, radius + 9, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(200, 50, 26, 0.14)";
        ctx.fill();
      }

      ctx.beginPath();
      ctx.arc(node.x!, node.y!, radius, 0, Math.PI * 2);
      ctx.fillStyle = isCompromised ? "#C8321A" : "#FBF9F4";
      ctx.fill();
      ctx.strokeStyle = isSelected ? "#17150F" : ring;
      ctx.lineWidth = isSelected ? 3 : 2.5;
      ctx.stroke();

      ctx.fillStyle = isCompromised ? "#FBF9F4" : ring;
      ctx.font = `600 11px ${font}`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(node.label.slice(0, 1).toUpperCase(), node.x!, node.y! + 0.5);

      ctx.fillStyle = "#17150F";
      ctx.font = `500 11px ${font}`;
      ctx.textBaseline = "alphabetic";
      ctx.fillText(node.label.slice(0, 14), node.x!, node.y! + radius + 16);

      if (!node.has2fa) {
        ctx.fillStyle = "#C8321A";
        ctx.fillRect(node.x! + radius * 0.55, node.y! - radius - 2, 7, 7);
      }
    });

    // Draw minimap
    const minimap = minimapRef.current;
    if (minimap) {
      const mCtx = minimap.getContext("2d");
      if (mCtx) {
        const scale = 150 / 800;
        const mh = 500 * scale;
        mCtx.clearRect(0, 0, 150, 150);
        mCtx.fillStyle = "#F2EEE5";
        mCtx.fillRect(0, 0, 150, 150);

        filteredEdges.forEach((edge) => {
          const source = nodes.find((n) => n.id === edge.source);
          const target = nodes.find((n) => n.id === edge.target);
          if (!source || !target) return;
          if (!visibleNodeIds.has(source.id) || !visibleNodeIds.has(target.id)) return;
          mCtx.beginPath();
          mCtx.moveTo(source.x! * scale, source.y! * scale + (150 - mh) / 2);
          mCtx.lineTo(target.x! * scale, target.y! * scale + (150 - mh) / 2);
          mCtx.strokeStyle = edgeColors[edge.type] || "#B8AE9A";
          mCtx.lineWidth = 0.5;
          mCtx.globalAlpha = 0.4;
          mCtx.stroke();
          mCtx.globalAlpha = 1;
        });

        filteredNodes.forEach((node) => {
          mCtx.beginPath();
          mCtx.arc(node.x! * scale, node.y! * scale + (150 - mh) / 2, 3, 0, Math.PI * 2);
          mCtx.fillStyle = riskColors[node.riskLevel] || "#B8AE9A";
          mCtx.fill();
        });
      }
    }
  }, [nodes, edges, filteredNodes, filteredEdges, selectedNode, attackResult]);

  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current!.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const clicked = nodes.find((n) => Math.sqrt((n.x! - x) ** 2 + (n.y! - y) ** 2) < 20);
    setSelectedNode(clicked || null);
  };

  const runAttackSimulation = async () => {
    if (!selectedNode) return;
    try {
      const res = await api.post(`/graph/simulate-attack?entry_account_id=${selectedNode.id}`);
      setAttackResult(res.data);
    } catch {}
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="eyebrow mb-3">Audit &middot; 03</p>
          <h1 className="page-title">Risk Graph</h1>
          <p className="text-[#5B544A] text-sm mt-1">Interactive map of your account connections</p>
        </div>
        <div className="flex gap-3">
          {selectedNode && (
            <button
              onClick={runAttackSimulation}
              className="px-5 py-2.5 bg-[#C8321A] hover:bg-[#A12813] text-white rounded-sm text-sm font-medium transition-all"
            >
              Simulate Attack on {selectedNode.label}
            </button>
          )}
          {attackResult && (
            <button
              onClick={() => setAttackResult(null)}
              className="px-5 py-2.5 bg-[#DCD4C4] hover:bg-[#B8AE9A] text-[#17150F] rounded-sm text-sm font-medium transition-all"
            >
              Clear Simulation
            </button>
          )}
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-xs text-[#8A8274] font-medium">Connection:</span>
        {connectionTypes.map((type) => (
          <button
            key={type}
            onClick={() => setEdgeFilter(type)}
            className={`px-3 py-1.5 rounded-sm text-xs font-medium transition-all ${
              edgeFilter === type
                ? "bg-[#17150F] text-white"
                : "bg-[#FBF9F4] text-[#5B544A] border border-[#DCD4C4] hover:border-[#B8AE9A]"
            }`}
          >
            {type}
          </button>
        ))}
        <div className="ml-2 flex items-center gap-2">
          <span className="text-xs text-[#8A8274] font-medium">Category:</span>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-1.5 bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm text-xs text-[#17150F] focus:outline-none focus:border-[#17150F] transition-all"
          >
            {categories.map((cat) => (
              <option key={cat} value={cat}>{cat === "All" ? "All Categories" : cat}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4 relative">
        <canvas
          ref={canvasRef}
          width={800}
          height={500}
          onClick={handleCanvasClick}
          className="w-full rounded-sm cursor-crosshair"
          style={{ background: "#F2EEE5" }}
        />
        {/* Minimap */}
        <div className="absolute bottom-6 right-6 border border-[#DCD4C4] rounded-sm overflow-hidden shadow-lg">
          <canvas
            ref={minimapRef}
            width={150}
            height={150}
            className="block"
            style={{ background: "#F2EEE5" }}
          />
        </div>
      </div>

      <div className="flex flex-wrap gap-4">
        {Object.entries(edgeColors).map(([type, color]) => (
          <div key={type} className="flex items-center gap-2">
            <div className="w-6 h-0.5" style={{ backgroundColor: color }} />
            <span className="text-xs text-[#5B544A] capitalize">{type.replace(/_/g, " ")}</span>
          </div>
        ))}
        <div className="ml-4 flex gap-4">
          {Object.entries(riskColors).map(([level, color]) => (
            <div key={level} className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full border-2 bg-[#FBF9F4]" style={{ borderColor: color }} />
              <span className="text-xs text-[#5B544A] capitalize">{level}</span>
            </div>
          ))}
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-[#C8321A]" />
            <span className="text-xs text-[#5B544A]">No 2FA</span>
          </div>
        </div>
      </div>

      {attackResult && (
        <div className="bg-[#FBF9F4] border border-[#C8321A]/30 rounded-sm p-6 animate-slide-up">
          <h2 className="section-title text-[#C8321A] mb-4">Attack Simulation Results</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <div className="bg-[#F2EEE5] rounded-sm p-4">
              <p className="text-sm text-[#5B544A]">Entry Point</p>
              <p className="text-lg font-bold text-[#C8321A]">{attackResult.entryPoint}</p>
            </div>
            <div className="bg-[#F2EEE5] rounded-sm p-4">
              <p className="text-sm text-[#5B544A]">Accounts Compromised</p>
              <p className="text-lg font-bold text-[#C8321A]">
                {attackResult.totalCompromised} / {attackResult.totalAccounts}
              </p>
            </div>
            <div className="bg-[#F2EEE5] rounded-sm p-4">
              <p className="text-sm text-[#5B544A]">Financial Accounts at Risk</p>
              <p className="text-lg font-bold text-[#A8660F]">{attackResult.financialAccountsAtRisk}</p>
            </div>
          </div>
          <div>
            <h3 className="text-sm font-medium text-[#5B544A] mb-2">Attack Chain</h3>
            <div className="flex flex-wrap gap-2">
              {attackResult.attackPath.map((step, i) => (
                <div key={i} className="flex items-center gap-2">
                  <span className="text-xs bg-[#C8321A]/20 text-[#C8321A] px-2 py-1 rounded">
                    {step.step}. {step.serviceName}
                  </span>
                  {i < attackResult.attackPath.length - 1 && (
                    <span className="text-[#8A8274]">&rarr;</span>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {selectedNode && !attackResult && (
        <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6 animate-slide-up">
          <h2 className="section-title mb-3">{selectedNode.label}</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div>
              <p className="text-xs text-[#5B544A]">Category</p>
              <p className="text-sm capitalize">{selectedNode.category}</p>
            </div>
            <div>
              <p className="text-xs text-[#5B544A]">Risk Score</p>
              <p className="text-sm" style={{ color: riskColors[selectedNode.riskLevel] }}>{selectedNode.riskScore.toFixed(0)}</p>
            </div>
            <div>
              <p className="text-xs text-[#5B544A]">2FA</p>
              <p className={`text-sm ${selectedNode.has2fa ? "text-[#2E6B4E]" : "text-[#C8321A]"}`}>
                {selectedNode.has2fa ? "Enabled" : "Disabled"}
              </p>
            </div>
            <div>
              <p className="text-xs text-[#5B544A]">Breaches</p>
              <p className="text-sm">{selectedNode.breachCount}</p>
            </div>
          </div>
        </div>
      )}

      {nodes.length === 0 && (
        <div className="text-center py-16">
          <p className="text-[#8A8274]">No accounts yet. Add accounts and connections to visualize your risk graph.</p>
        </div>
      )}
    </div>
  );
}
