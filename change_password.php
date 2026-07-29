<?php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/config.php';

date_default_timezone_set("Asia/Kuala_Lumpur");

function respond($status, $message, $extra = []) {
    echo json_encode(array_merge([
        "status" => $status,
        "message" => $message,
    ], $extra));
    exit;
}

$staff_id = trim($_POST['staff_id'] ?? '');
$staff_no = trim($_POST['staff_no'] ?? '');
$current_password = $_POST['current_password'] ?? '';
$new_password = $_POST['new_password'] ?? '';

if ($staff_id === '' && $staff_no === '') {
    respond("error", "Missing staff identifier.");
}

if ($current_password === '' || $new_password === '') {
    respond("error", "Missing required fields.");
}

if (strlen($new_password) < 6) {
    respond("error", "New password must be at least 6 characters.");
}

if ($current_password === $new_password) {
    respond("error", "New password must be different from current password.");
}

try {
    if ($staff_id !== '') {
        $stmt = $conn->prepare("
            SELECT staff_id, staff_no, staff_pass
            FROM staff
            WHERE staff_id = ?
            LIMIT 1
        ");

        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }

        $stmt->bind_param("s", $staff_id);
    } else {
        $stmt = $conn->prepare("
            SELECT staff_id, staff_no, staff_pass
            FROM staff
            WHERE staff_no = ?
            LIMIT 1
        ");

        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }

        $stmt->bind_param("s", $staff_no);
    }

    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }

    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        respond("error", "Staff record not found.");
    }

    $staff = $result->fetch_assoc();
    $stmt->close();

    if (($staff['staff_pass'] ?? '') !== $current_password) {
        respond("error", "Current password is incorrect.");
    }

    $staff_id_to_update = $staff['staff_id'];

    $updateStmt = $conn->prepare("
        UPDATE staff
        SET staff_pass = ?, updated_at = NOW()
        WHERE staff_id = ?
    ");

    if (!$updateStmt) {
        throw new Exception("Prepare update failed: " . $conn->error);
    }

    $updateStmt->bind_param("ss", $new_password, $staff_id_to_update);

    if ($updateStmt->execute()) {
        respond("success", "Password updated successfully.");
    }

    throw new Exception("Update failed: " . $updateStmt->error);
} catch (Exception $e) {
    respond("error", "Database Error: " . $e->getMessage());
}

$conn->close();
?>
