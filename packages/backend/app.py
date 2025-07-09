@app.route("/api/monitors/<int:monitor_id>", methods=["DELETE"])
@verify_iap_jwt
def delete_monitor(monitor_id):
    """Deletes a monitor."""
    try:
        conn = get_conn()
        cursor = conn.cursor()

        # Optional: Check if the monitor belongs to the user
        cursor.execute("SELECT user_email, schedule FROM monitors WHERE id = %s", (monitor_id,))
        result = cursor.fetchone()
        if not result or result[0] != g.user_email:
            return jsonify({"error": "Monitor not found or access denied"}), 404

        schedule = result[1]
        if schedule:
            scheduler.delete_schedule(monitor_id)

        cursor.execute("DELETE FROM monitors WHERE id = %s", (monitor_id,))
        if schedule:
            scheduler.create_schedule(monitor_id, schedule)

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"message": "Monitor deleted"}), 200
    except Exception as e:
        app.logger.error(f"Database error: {e}")
        return jsonify({"error": "Could not delete monitor"}), 500