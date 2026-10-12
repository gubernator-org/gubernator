/// Observability, Sloth SLO, CoreDNS, Loki Logs, and eBPF Telemetry models.
library;

class SLOItem {
  final String serviceId;
  final String serviceName;
  final String stackId;
  final double target;
  final String window;
  final String template;
  final String journey;
  final String errorQuery;
  final String totalQuery;
  final double errorBudgetRemaining;
  final double burnRate;
  final String status;
  final String indicator;
  final String latencyThreshold;

  SLOItem({
    required this.serviceId,
    required this.serviceName,
    required this.stackId,
    required this.target,
    required this.window,
    this.indicator = 'ratio',
    this.latencyThreshold = '',
    this.template = '',
    this.journey = '',
    required this.errorQuery,
    required this.totalQuery,
    required this.errorBudgetRemaining,
    required this.burnRate,
    required this.status,
  });

  factory SLOItem.fromJson(Map<String, dynamic> json) {
    return SLOItem(
      serviceId: json['service_id'] ?? '',
      serviceName: json['service_name'] ?? '',
      stackId: json['stack_id'] ?? '',
      target: (json['target'] as num?)?.toDouble() ?? 99.9,
      window: json['window'] ?? '30d',
      indicator: json['indicator'] ?? 'ratio',
      latencyThreshold: json['latency_threshold'] ?? '',
      template: json['template'] ?? '',
      journey: json['journey'] ?? '',
      errorQuery: json['error_query'] ?? '',
      totalQuery: json['total_query'] ?? '',
      errorBudgetRemaining: (json['error_budget_remaining'] as num?)?.toDouble() ?? 100.0,
      burnRate: (json['burn_rate'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'healthy',
    );
  }
}

class UserJourney {
  final String name;
  final List<SLOItem> services;
  final double compositeTarget;
  final double avgErrorBudget;
  final String bottleneckService;
  final double bottleneckBudget;
  final String status;

  UserJourney({
    required this.name,
    required this.services,
    required this.compositeTarget,
    required this.avgErrorBudget,
    required this.bottleneckService,
    required this.bottleneckBudget,
    required this.status,
  });

  factory UserJourney.fromJson(Map<String, dynamic> json) {
    return UserJourney(
      name: json['name'] ?? '',
      services: (json['services'] as List? ?? []).map((e) => SLOItem.fromJson(e)).toList(),
      compositeTarget: (json['composite_target'] as num?)?.toDouble() ?? 99.9,
      avgErrorBudget: (json['avg_error_budget'] as num?)?.toDouble() ?? 100.0,
      bottleneckService: json['bottleneck_service'] ?? '',
      bottleneckBudget: (json['bottleneck_budget'] as num?)?.toDouble() ?? 100.0,
      status: json['status'] ?? 'healthy',
    );
  }
}

class SLOCorrelationEvent {
  final String timestamp;
  final String type;
  final String stackName;
  final String serviceName;
  final String description;
  final double burnRate;

  SLOCorrelationEvent({
    required this.timestamp,
    required this.type,
    required this.stackName,
    required this.serviceName,
    required this.description,
    required this.burnRate,
  });

  factory SLOCorrelationEvent.fromJson(Map<String, dynamic> json) {
    return SLOCorrelationEvent(
      timestamp: json['timestamp'] ?? '',
      type: json['type'] ?? 'deployment',
      stackName: json['stack_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      description: json['description'] ?? '',
      burnRate: (json['burn_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SLOValidationItem {
  final String serviceName;
  final bool valid;
  final double target;
  final String window;
  final String template;
  final String errorQuery;
  final String totalQuery;
  final String error;
  final String backtestStatus;
  final String backtestDetails;

  SLOValidationItem({
    required this.serviceName,
    required this.valid,
    required this.target,
    required this.window,
    required this.template,
    required this.errorQuery,
    required this.totalQuery,
    this.error = '',
    required this.backtestStatus,
    required this.backtestDetails,
  });

  factory SLOValidationItem.fromJson(Map<String, dynamic> json) {
    return SLOValidationItem(
      serviceName: json['service_name'] ?? '',
      valid: json['valid'] ?? false,
      target: (json['target'] as num?)?.toDouble() ?? 99.9,
      window: json['window'] ?? '30d',
      template: json['template'] ?? '',
      errorQuery: json['error_query'] ?? '',
      totalQuery: json['total_query'] ?? '',
      error: json['error'] ?? '',
      backtestStatus: json['backtest_status'] ?? 'passed',
      backtestDetails: json['backtest_details'] ?? '',
    );
  }
}

class SLOHistoryPoint {
  final String timestamp;
  final double budgetRemaining;
  final double burnRate;

  SLOHistoryPoint({
    required this.timestamp,
    required this.budgetRemaining,
    required this.burnRate,
  });

  factory SLOHistoryPoint.fromJson(Map<String, dynamic> json) {
    return SLOHistoryPoint(
      timestamp: json['timestamp'] ?? '',
      budgetRemaining: (json['budget_remaining'] as num?)?.toDouble() ?? 100.0,
      burnRate: (json['burn_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SLOREDMetrics {
  final double rps;
  final double errorRps;
  final double p99LatencyMs;

  SLOREDMetrics({
    required this.rps,
    required this.errorRps,
    required this.p99LatencyMs,
  });

  factory SLOREDMetrics.fromJson(Map<String, dynamic> json) {
    return SLOREDMetrics(
      rps: (json['rps'] as num?)?.toDouble() ?? 0.0,
      errorRps: (json['error_rps'] as num?)?.toDouble() ?? 0.0,
      p99LatencyMs: (json['p99_latency_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomDNSRecord {
  final String id;
  final String domain;
  final String ip;
  final String recordType;
  final int ttl;
  final String createdAt;

  CustomDNSRecord({
    required this.id,
    required this.domain,
    required this.ip,
    required this.recordType,
    required this.ttl,
    required this.createdAt,
  });

  factory CustomDNSRecord.fromJson(Map<String, dynamic> json) {
    return CustomDNSRecord(
      id: json['id'] ?? '',
      domain: json['domain'] ?? '',
      ip: json['ip'] ?? '',
      recordType: json['record_type'] ?? 'A',
      ttl: (json['ttl'] as num?)?.toInt() ?? 60,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DNSDigAnswer {
  final String name;
  final String type;
  final int ttl;
  final String data;

  DNSDigAnswer({
    required this.name,
    required this.type,
    required this.ttl,
    required this.data,
  });

  factory DNSDigAnswer.fromJson(Map<String, dynamic> json) {
    return DNSDigAnswer(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      ttl: (json['ttl'] as num?)?.toInt() ?? 60,
      data: json['data'] ?? '',
    );
  }
}

class DNSDigResult {
  final String domain;
  final String recordType;
  final String status;
  final double queryTimeMs;
  final String server;
  final List<DNSDigAnswer> answers;
  final String rawOutput;

  DNSDigResult({
    required this.domain,
    required this.recordType,
    required this.status,
    required this.queryTimeMs,
    required this.server,
    required this.answers,
    required this.rawOutput,
  });

  factory DNSDigResult.fromJson(Map<String, dynamic> json) {
    return DNSDigResult(
      domain: json['domain'] ?? '',
      recordType: json['record_type'] ?? 'A',
      status: json['status'] ?? '',
      queryTimeMs: (json['query_time_ms'] as num?)?.toDouble() ?? 0.0,
      server: json['server'] ?? '',
      answers: (json['answers'] as List? ?? []).map((e) => DNSDigAnswer.fromJson(e)).toList(),
      rawOutput: json['raw_output'] ?? '',
    );
  }
}

class DNSCurlResult {
  final String command;
  final int statusCode;
  final String statusText;
  final double latencyMs;
  final String headers;
  final String body;
  final String rawOutput;
  final String targetIp;
  final bool success;
  final String? error;

  DNSCurlResult({
    required this.command,
    required this.statusCode,
    required this.statusText,
    required this.latencyMs,
    required this.headers,
    required this.body,
    required this.rawOutput,
    required this.targetIp,
    required this.success,
    this.error,
  });

  factory DNSCurlResult.fromJson(Map<String, dynamic> json) {
    return DNSCurlResult(
      command: json['command'] ?? '',
      statusCode: json['status_code'] ?? 0,
      statusText: json['status_text'] ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      headers: json['headers'] ?? '',
      body: json['body'] ?? '',
      rawOutput: json['raw_output'] ?? '',
      targetIp: json['target_ip'] ?? '',
      success: json['success'] ?? false,
      error: json['error'],
    );
  }
}

class DNSPingResult {
  final String command;
  final String target;
  final int packetsSent;
  final int packetsRecv;
  final double packetLoss;
  final double minLatency;
  final double avgLatency;
  final double maxLatency;
  final String rawOutput;
  final bool success;
  final String? error;

  DNSPingResult({
    required this.command,
    required this.target,
    required this.packetsSent,
    required this.packetsRecv,
    required this.packetLoss,
    required this.minLatency,
    required this.avgLatency,
    required this.maxLatency,
    required this.rawOutput,
    required this.success,
    this.error,
  });

  factory DNSPingResult.fromJson(Map<String, dynamic> json) {
    return DNSPingResult(
      command: json['command'] ?? '',
      target: json['target'] ?? '',
      packetsSent: json['packets_sent'] ?? 0,
      packetsRecv: json['packets_recv'] ?? 0,
      packetLoss: (json['packet_loss'] as num?)?.toDouble() ?? 0.0,
      minLatency: (json['min_latency'] as num?)?.toDouble() ?? 0.0,
      avgLatency: (json['avg_latency'] as num?)?.toDouble() ?? 0.0,
      maxLatency: (json['max_latency'] as num?)?.toDouble() ?? 0.0,
      rawOutput: json['raw_output'] ?? '',
      success: json['success'] ?? false,
      error: json['error'],
    );
  }
}

class CoreDNSStatusInfo {
  final String status;
  final int uptimeSeconds;
  final int memBytes;
  final int listeningPort;
  final List<String> forwarders;
  final int totalRecords;
  final String? managerIp;
  final String? corednsIp;
  final String clusterDomain;

  CoreDNSStatusInfo({
    required this.status,
    required this.uptimeSeconds,
    required this.memBytes,
    required this.listeningPort,
    required this.forwarders,
    required this.totalRecords,
    this.managerIp,
    this.corednsIp,
    this.clusterDomain = 'gbnt.local',
  });

  factory CoreDNSStatusInfo.fromJson(Map<String, dynamic> json) {
    return CoreDNSStatusInfo(
      status: json['status'] ?? 'stopped',
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      memBytes: (json['mem_bytes'] as num?)?.toInt() ?? 0,
      listeningPort: (json['listening_port'] as num?)?.toInt() ?? 5354,
      forwarders: (json['forwarders'] as List? ?? []).map((e) => e.toString()).toList(),
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      managerIp: json['manager_ip']?.toString(),
      corednsIp: json['coredns_ip']?.toString(),
      clusterDomain: json['cluster_domain']?.toString() ?? 'gbnt.local',
    );
  }
}

class LokiLogEntry {
  final String timestamp;
  final String timestampNs;
  final String container;
  final String node;
  final String stack;
  final String stream;
  final String level;
  final String message;
  final Map<String, String> labels;

  LokiLogEntry({
    required this.timestamp,
    required this.timestampNs,
    required this.container,
    required this.node,
    required this.stack,
    required this.stream,
    required this.level,
    required this.message,
    this.labels = const {},
  });

  factory LokiLogEntry.fromJson(Map<String, dynamic> json) {
    Map<String, String> labelsMap = {};
    if (json['labels'] != null && json['labels'] is Map) {
      (json['labels'] as Map).forEach((k, v) {
        labelsMap[k.toString()] = v.toString();
      });
    }

    return LokiLogEntry(
      timestamp: json['timestamp']?.toString() ?? '',
      timestampNs: json['timestamp_ns']?.toString() ?? '',
      container: json['container']?.toString() ?? '',
      node: json['node']?.toString() ?? 'manager',
      stack: json['stack']?.toString() ?? '',
      stream: json['stream']?.toString() ?? 'stdout',
      level: json['level']?.toString() ?? 'INFO',
      message: json['message']?.toString() ?? '',
      labels: labelsMap,
    );
  }
}

class LokiLabelsResponse {
  final List<String> containers;
  final List<String> nodes;
  final List<String> stacks;
  final List<String> streams;
  final List<String> levels;

  LokiLabelsResponse({
    required this.containers,
    required this.nodes,
    required this.stacks,
    required this.streams,
    required this.levels,
  });

  factory LokiLabelsResponse.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null || raw is! List) return [];
      return raw.map((e) => e.toString()).toList();
    }

    List<String> nodeNames = [];
    if (json['nodes'] != null && json['nodes'] is List) {
      for (var item in json['nodes']) {
        if (item is Map && item['name'] != null) {
          nodeNames.add(item['name'].toString());
        } else if (item is Map && item['id'] != null) {
          nodeNames.add(item['id'].toString());
        } else {
          nodeNames.add(item.toString());
        }
      }
    }

    List<String> stackNames = [];
    if (json['stacks'] != null && json['stacks'] is List) {
      for (var item in json['stacks']) {
        if (item is Map && item['name'] != null) {
          stackNames.add(item['name'].toString());
        } else {
          stackNames.add(item.toString());
        }
      }
    }

    return LokiLabelsResponse(
      containers: parseList(json['containers']),
      nodes: nodeNames,
      stacks: stackNames,
      streams: parseList(json['streams']),
      levels: parseList(json['levels']),
    );
  }
}

// ── eBPF Live Hub Models ──────────────────────────────────────────────────

class EbpfInterfaceStats {
  final String name;
  final int rxBytes;
  final int txBytes;
  final int rxPackets;
  final int txPackets;
  final int rxErrors;
  final int txErrors;
  final int rxDrops;
  final int txDrops;

  EbpfInterfaceStats({
    required this.name,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.rxPackets = 0,
    this.txPackets = 0,
    this.rxErrors = 0,
    this.txErrors = 0,
    this.rxDrops = 0,
    this.txDrops = 0,
  });

  factory EbpfInterfaceStats.fromJson(Map<String, dynamic> json) {
    return EbpfInterfaceStats(
      name: json['name'] ?? '',
      rxBytes: (json['rx_bytes'] as num?)?.toInt() ?? 0,
      txBytes: (json['tx_bytes'] as num?)?.toInt() ?? 0,
      rxPackets: (json['rx_packets'] as num?)?.toInt() ?? 0,
      txPackets: (json['tx_packets'] as num?)?.toInt() ?? 0,
      rxErrors: (json['rx_errors'] as num?)?.toInt() ?? 0,
      txErrors: (json['tx_errors'] as num?)?.toInt() ?? 0,
      rxDrops: (json['rx_drops'] as num?)?.toInt() ?? 0,
      txDrops: (json['tx_drops'] as num?)?.toInt() ?? 0,
    );
  }
}

class EbpfStats {
  final String kernelVersion;
  final bool ebpfSupported;
  final String mode;
  final int activeProbes;
  final List<String> probesList;
  final int totalFlows;
  final int activeFlows;
  final double packetsPerSec;
  final double bytesPerSec;
  final int droppedPackets;
  final List<EbpfInterfaceStats> interfaces;
  final Map<String, int> protocolCounts;
  final Map<String, int> statusCounts;

  EbpfStats({
    required this.kernelVersion,
    required this.ebpfSupported,
    this.mode = 'kernel',
    this.activeProbes = 0,
    this.probesList = const [],
    this.totalFlows = 0,
    this.activeFlows = 0,
    this.packetsPerSec = 0.0,
    this.bytesPerSec = 0.0,
    this.droppedPackets = 0,
    this.interfaces = const [],
    this.protocolCounts = const {},
    this.statusCounts = const {},
  });

  factory EbpfStats.fromJson(Map<String, dynamic> json) {
    final ifacesList = <EbpfInterfaceStats>[];
    if (json['interfaces'] != null && json['interfaces'] is List) {
      for (final item in json['interfaces']) {
        if (item is Map<String, dynamic>) {
          ifacesList.add(EbpfInterfaceStats.fromJson(item));
        }
      }
    }

    final probes = <String>[];
    if (json['probes_list'] != null && json['probes_list'] is List) {
      for (final p in json['probes_list']) {
        probes.add(p.toString());
      }
    }

    final protoCounts = <String, int>{};
    if (json['protocol_counts'] != null && json['protocol_counts'] is Map) {
      json['protocol_counts'].forEach((k, v) {
        protoCounts[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    final statCounts = <String, int>{};
    if (json['status_counts'] != null && json['status_counts'] is Map) {
      json['status_counts'].forEach((k, v) {
        statCounts[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return EbpfStats(
      kernelVersion: json['kernel_version'] ?? '',
      ebpfSupported: json['ebpf_supported'] == true,
      mode: json['mode'] ?? 'kernel',
      activeProbes: (json['active_probes'] as num?)?.toInt() ?? 0,
      probesList: probes,
      totalFlows: (json['total_flows'] as num?)?.toInt() ?? 0,
      activeFlows: (json['active_flows'] as num?)?.toInt() ?? 0,
      packetsPerSec: (json['packets_per_sec'] as num?)?.toDouble() ?? 0.0,
      bytesPerSec: (json['bytes_per_sec'] as num?)?.toDouble() ?? 0.0,
      droppedPackets: (json['dropped_packets'] as num?)?.toInt() ?? 0,
      interfaces: ifacesList,
      protocolCounts: protoCounts,
      statusCounts: statCounts,
    );
  }
}

class EbpfFlow {
  final String id;
  final String sourceId;
  final String sourceName;
  final String sourceIp;
  final int sourcePort;
  final String destId;
  final String destName;
  final String destIp;
  final int destPort;
  final String protocol;
  final String method;
  final String path;
  final int statusCode;
  final double latencyMs;
  final int bytesSent;
  final int bytesReceived;
  final double throughputBps;
  final int retransmits;
  final int drops;
  final String traceId;
  final String status;
  final DateTime timestamp;

  EbpfFlow({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceIp,
    this.sourcePort = 0,
    required this.destId,
    required this.destName,
    required this.destIp,
    this.destPort = 0,
    required this.protocol,
    this.method = '',
    this.path = '',
    this.statusCode = 0,
    this.latencyMs = 0.0,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.throughputBps = 0.0,
    this.retransmits = 0,
    this.drops = 0,
    this.traceId = '',
    required this.status,
    required this.timestamp,
  });

  factory EbpfFlow.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    if (json['timestamp'] != null) {
      ts = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }

    return EbpfFlow(
      id: json['id'] ?? '',
      sourceId: json['source_id'] ?? '',
      sourceName: json['source_name'] ?? '',
      sourceIp: json['source_ip'] ?? '',
      sourcePort: (json['source_port'] as num?)?.toInt() ?? 0,
      destId: json['dest_id'] ?? '',
      destName: json['dest_name'] ?? '',
      destIp: json['dest_ip'] ?? '',
      destPort: (json['dest_port'] as num?)?.toInt() ?? 0,
      protocol: json['protocol'] ?? 'TCP',
      method: json['method'] ?? '',
      path: json['path'] ?? '',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
      bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
      throughputBps: (json['throughput_bps'] as num?)?.toDouble() ?? 0.0,
      retransmits: (json['retransmits'] as num?)?.toInt() ?? 0,
      drops: (json['drops'] as num?)?.toInt() ?? 0,
      traceId: json['trace_id'] ?? '',
      status: json['status'] ?? 'healthy',
      timestamp: ts,
    );
  }
}

class EbpfTopologyNode {
  final String id;
  final String name;
  final String type;
  final String stack;
  final String nodeHost;
  final String ip;
  final String status;
  final double inboundBps;
  final double outboundBps;
  final int activeFlows;
  final double errorRate;
  final double cpuPercent;
  final double memPercent;

  EbpfTopologyNode({
    required this.id,
    required this.name,
    required this.type,
    this.stack = '',
    this.nodeHost = '',
    this.ip = '',
    this.status = 'running',
    this.inboundBps = 0.0,
    this.outboundBps = 0.0,
    this.activeFlows = 0,
    this.errorRate = 0.0,
    this.cpuPercent = 0.0,
    this.memPercent = 0.0,
  });

  factory EbpfTopologyNode.fromJson(Map<String, dynamic> json) {
    return EbpfTopologyNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'container',
      stack: json['stack'] ?? '',
      nodeHost: json['node_host'] ?? '',
      ip: json['ip'] ?? '',
      status: json['status'] ?? 'running',
      inboundBps: (json['inbound_bps'] as num?)?.toDouble() ?? 0.0,
      outboundBps: (json['outbound_bps'] as num?)?.toDouble() ?? 0.0,
      activeFlows: (json['active_flows'] as num?)?.toInt() ?? 0,
      errorRate: (json['error_rate'] as num?)?.toDouble() ?? 0.0,
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memPercent: (json['mem_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EbpfTopologyEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String protocol;
  final double throughputBps;
  final double rttMs;
  final int activeFlows;
  final double errorRate;
  final String traceId;
  final String status;
  final DateTime lastSeen;

  EbpfTopologyEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.protocol,
    this.throughputBps = 0.0,
    this.rttMs = 0.0,
    this.activeFlows = 0,
    this.errorRate = 0.0,
    this.traceId = '',
    this.status = 'healthy',
    required this.lastSeen,
  });

  factory EbpfTopologyEdge.fromJson(Map<String, dynamic> json) {
    DateTime ls = DateTime.now();
    if (json['last_seen'] != null) {
      ls = DateTime.tryParse(json['last_seen'].toString()) ?? DateTime.now();
    }
    return EbpfTopologyEdge(
      id: json['id'] ?? '',
      sourceId: json['source_id'] ?? '',
      targetId: json['target_id'] ?? '',
      protocol: json['protocol'] ?? 'TCP',
      throughputBps: (json['throughput_bps'] as num?)?.toDouble() ?? 0.0,
      rttMs: (json['rtt_ms'] as num?)?.toDouble() ?? 0.0,
      activeFlows: (json['active_flows'] as num?)?.toInt() ?? 0,
      errorRate: (json['error_rate'] as num?)?.toDouble() ?? 0.0,
      traceId: json['trace_id'] ?? '',
      status: json['status'] ?? 'healthy',
      lastSeen: ls,
    );
  }
}

class EbpfTopology {
  final List<EbpfTopologyNode> nodes;
  final List<EbpfTopologyEdge> edges;
  final DateTime updatedAt;

  EbpfTopology({
    required this.nodes,
    required this.edges,
    required this.updatedAt,
  });

  factory EbpfTopology.fromJson(Map<String, dynamic> json) {
    final nList = <EbpfTopologyNode>[];
    if (json['nodes'] != null && json['nodes'] is List) {
      for (final n in json['nodes']) {
        if (n is Map<String, dynamic>) {
          nList.add(EbpfTopologyNode.fromJson(n));
        }
      }
    }

    final eList = <EbpfTopologyEdge>[];
    if (json['edges'] != null && json['edges'] is List) {
      for (final e in json['edges']) {
        if (e is Map<String, dynamic>) {
          eList.add(EbpfTopologyEdge.fromJson(e));
        }
      }
    }

    DateTime u = DateTime.now();
    if (json['updated_at'] != null) {
      u = DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    }

    return EbpfTopology(
      nodes: nList,
      edges: eList,
      updatedAt: u,
    );
  }
}
