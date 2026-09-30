"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface Notification {
  id: number;
  title: string;
  message: string;
  severity: string;
  is_read: boolean;
  related_account_id: number | null;
  created_at: string;
}

const severityColors: Record<string, string> = {
  critical: "#C8321A",
  warning: "#A8660F",
  info: "#23408E",
};

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/notifications/").then((r) => setNotifications(r.data)).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const markRead = async (id: number) => {
    await api.patch(`/notifications/${id}/read`);
    setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, is_read: true } : n)));
  };

  const markAllRead = async () => {
    await api.patch("/notifications/read-all");
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const unread = notifications.filter((n) => !n.is_read).length;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="eyebrow mb-3">Inbox</p>
          <h1 className="page-title">Notifications</h1>
          <p className="text-[#5B544A] text-sm mt-1">{unread} unread notification{unread !== 1 ? "s" : ""}</p>
        </div>
        {unread > 0 && (
          <button
            onClick={markAllRead}
            className="px-4 py-2 bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm text-sm text-[#5B544A] hover:text-[#17150F] transition-all"
          >
            Mark all read
          </button>
        )}
      </div>

      <div className="space-y-3">
        {notifications.map((n) => {
          const color = severityColors[n.severity] || "#23408E";
          return (
            <div
              key={n.id}
              className={`bg-[#FBF9F4] border rounded-sm p-4 transition-all cursor-pointer ${
                n.is_read ? "border-[#DCD4C4] opacity-70" : `border-l-4`
              }`}
              style={!n.is_read ? { borderLeftColor: color } : {}}
              onClick={() => !n.is_read && markRead(n.id)}
            >
              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-sm flex items-center justify-center flex-shrink-0" style={{ backgroundColor: `${color}20` }}>
                  {n.severity === "critical" ? (
                    <svg className="w-4 h-4" style={{ color }} fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495z" clipRule="evenodd" />
                    </svg>
                  ) : (
                    <svg className="w-4 h-4" style={{ color }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
                    </svg>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="font-medium text-sm">{n.title}</h3>
                    <span className="text-[10px] px-1.5 py-0.5 rounded uppercase" style={{ backgroundColor: `${color}20`, color }}>
                      {n.severity}
                    </span>
                    {!n.is_read && <span className="w-2 h-2 rounded-full bg-[#23408E]" />}
                  </div>
                  <p className="text-sm text-[#5B544A] mt-1">{n.message}</p>
                  {n.created_at && (
                    <p className="text-[10px] text-[#8A8274] mt-2">{new Date(n.created_at).toLocaleString()}</p>
                  )}
                </div>
              </div>
            </div>
          );
        })}
        {notifications.length === 0 && (
          <div className="text-center py-16">
            <p className="text-[#8A8274]">No notifications yet. They&apos;ll appear here when breaches are detected or actions are needed.</p>
          </div>
        )}
      </div>
    </div>
  );
}
