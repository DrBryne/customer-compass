import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import { useParams } from 'react-router-dom';

function Report() {
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const { monitorId } = useParams();

  const fetchReport = useCallback(() => {
    axios.get(`/api/monitors/${monitorId}/report`)
      .then(response => {
        setReport(response.data);
      })
      .catch(error => {
        console.error('Error fetching report:', error);
      });
  }, [monitorId]);

  const runMonitor = () => {
    setLoading(true);
    axios.post(`/api/monitors/${monitorId}/run`)
      .then(response => {
        setReport(response.data);
        setLoading(false);
      })
      .catch(error => {
        console.error('Error running monitor:', error);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchReport();
  }, [fetchReport]);

  const renderSummary = (summary, sources) => {
    const parts = summary.split(/(\[Source \d+\])/g);
    return parts.map((part, index) => {
      const match = part.match(/\[Source (\d+)\]/);
      if (match) {
        const sourceIndex = parseInt(match[1], 10) - 1;
        if (sources[sourceIndex]) {
          return (
            <a key={index} href={sources[sourceIndex].url} target="_blank" rel="noopener noreferrer">
              {part}
            </a>
          );
        }
      }
      return part;
    });
  };

  return (
    <div>
      <h2>Report for Monitor {monitorId}</h2>
      <button onClick={runMonitor} disabled={loading}>
        {loading ? 'Running...' : 'Run Monitor Now'}
      </button>
      {report ? (
        <div>
          <h3>Summary</h3>
          <p>{renderSummary(report.report.summary, report.report.sources)}</p>
          <h4>Sources</h4>
          <ul>
            {report.report.sources.map((source, index) => (
              <li key={index}>
                <a href={source.url} target="_blank" rel="noopener noreferrer">{source.title}</a>
              </li>
            ))}
          </ul>
        </div>
      ) : (
        <p>No report available. Run the monitor to generate one.</p>
      )}
    </div>
  );
}

export default Report;