import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';

function Dashboard() {
  const [monitors, setMonitors] = useState([]);

  useEffect(() => {
    axios.get('/api/monitors')
      .then(response => {
        setMonitors(response.data);
      })
      .catch(error => {
        console.error('Error fetching monitors:', error);
      });
  }, []);

  return (
    <div>
      <h2>Dashboard</h2>
      <Link to="/create">Create New Monitor</Link>
      <ul>
        {monitors.map(monitor => (
          <li key={monitor.id}>
            <h3>{monitor.name}</h3>
            <p>Recency: {monitor.recency_days} days</p>
            <p>Schedule: {monitor.schedule}</p>
            <p>Organizations: {monitor.organizations.join(', ')}</p>
            <p>Areas of Interest: {monitor.areas_of_interest.join(', ')}</p>
            <Link to={`/report/${monitor.id}`}>View Latest Report</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default Dashboard;