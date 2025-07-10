import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { TagInput } from '@eidellev/react-tag-input';
import '@eidellev/react-tag-input/dist/index.css';
import Slider from 'rc-slider';
import 'rc-slider/assets/index.css';

function CreateMonitor() {
  const [name, setName] = useState('');
  const [organizations, setOrganizations] = useState([]);
  const [areasOfInterest, setAreasOfInterest] = useState([]);
  const [recencyDays, setRecencyDays] = useState(14);
  const [schedule, setSchedule] = useState('weekly');
  const navigate = useNavigate();

  const handleSubmit = (event) => {
    event.preventDefault();
    const data = {
      name,
      organizations: organizations.map(org => org.value),
      areas_of_interest: areasOfInterest.map(area => area.value),
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
        Organizations:
        <TagInput
          tags={organizations}
          onTagsChanged={setOrganizations}
        />
      </label>
      <label>
        Areas of Interest:
        <TagInput
          tags={areasOfInterest}
          onTagsChanged={setAreasOfInterest}
        />
      </label>
      <label>
        Recency (days):
        <Slider min={1} max={90} value={recencyDays} onChange={setRecencyDays} />
        <span>{recencyDays}</span>
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