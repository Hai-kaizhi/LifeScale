import { Result } from 'antd';

interface PlaceholderPageProps {
  title?: string;
}

export function PlaceholderPage({ title = '该功能暂未开发' }: PlaceholderPageProps) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
      <Result status="info" title={title} subTitle="该功能即将上线，敬请期待" />
    </div>
  );
}
