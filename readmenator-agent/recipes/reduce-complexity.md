# Recipe: Reduce File Complexity

Target hotspot: `generate_blocklist.sh`
(complexity 1.0, centrality 0.0)

1. Read dependents: `grep -n 'generate_blocklist.sh' readmenator-agent/ARCHITECTURE.md`
2. Extract functions/classes into new files in the same subsystem
3. Update imports
4. Regenerate: `readmenator .`
