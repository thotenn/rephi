import { useAuthStore } from "@rephi/shared-components";
import Layout from "~/components/bedrock/Layout";
import ChangePasswordForm from "~/components/ChangePasswordForm";
import UserInfo from "~/components/UserInfo";

export default function Profile() {
  const user = useAuthStore((state) => state.user);

  return (
    <Layout title="User Profile">
      <UserInfo user={user} showPermissions />
      <ChangePasswordForm />
    </Layout>
  );
}
