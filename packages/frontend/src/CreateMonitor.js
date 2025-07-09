import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

function CreateMonitor() {
  const [name, setName] = useState('');
  const [organizations, setOrganizations] = useState('');
  const [areasOfInterest, setAreasOfInterest] = useState('');
  const [recencyDays, setRecencyDays] = useState(14);
  const [schedule, setSchedule] = useState('weekly');
  const navigate = useNavigate();

  const handleSubmit = (event) => {
    event.preventDefault();
    const data = {
      name,
      organizations: organizations.split(',').map(s => s.trim()),
      areas_of_interest: areasOfInterest.split(',').map(s => s.trim()),
      recency_days: recencyDays,
      schedule,
    };
    axios.post('/api/monitors', data)
      .then(() => {
        navigate('/');
      })
      .catch(error => {
        console.error('Error creating monitor:', error);
      });
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Create Monitor</h2>
      <label>
        Name:
        <input type="text" value={name} onChange={e => setName(e.target.value)} />
      </label>
      <label>
        Organizations (comma-separated):
        <input type="text" value={organizations} onChange={e => setOrganizations(e.target.value)} />
      </label>
      <label>
        Areas of Interest (comma-separated):
        <input type="text" value={areasOfInterest} onChange={e => setAreasOfInterest(e.target.value)} />
      </label>
      <label>
        Recency (days):
        <input type="number" value={recencyDays} onChange={e => setRecencyDays(parseInt(e.target.value, 10))} />
      </label>
      <label>
        Schedule:
        <select value={schedule} onChange={e => setSchedule(e.target.value)}>
          <option value="daily">Daily</option>
          <option value="weekly">Weekly</option>
          <option value="monthly">Monthly</option>
        </select>
      </label>
      <button type="submit">Create</button>
    </form>
  );
}

export default CreateMonitor;