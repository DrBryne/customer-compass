
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useParams } from 'react-router-dom';

function Report() {
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const { monitorId } = useParams();

  const fetchReport = () => {
    axios.get(`/api/monitors/${monitorId}/report`)
      .then(response => {
        setReport(response.data);
      })
      .catch(error => {
        console.error('Error fetching report:', error);
      });
  };

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
  }, [monitorId]);

  return (
    <div>
      <h2>Report for Monitor {monitorId}</h2>
      <button onClick={runMonitor} disabled={loading}>
        {loading ? 'Running...' : 'Run Monitor Now'}
      </button>
      {report ? (
        <div>
          <h3>Summary</h3>
          <p>{report.report.summary}</p>
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
