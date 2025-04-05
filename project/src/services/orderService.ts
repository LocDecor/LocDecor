import { supabase } from '../lib/supabase';
import { Order, Client, InventoryItem } from '../types/database';
import jsPDF from 'jspdf';

export interface OrderInput {
  client_id: string;
  plan: string;
  pickup_date: string;
  pickup_time: string;
  return_date: string;
  return_time: string;
  total_amount: number;
  payment_method?: string;
  notes?: string;
  items: Array<{
    item_id: string;
    quantity: number;
    unit_price: number;
  }>;
}

export const orderService = {
  async getClients(searchTerm?: string): Promise<Client[]> {
    let query = supabase
      .from('clients')
      .select('*')
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (searchTerm) {
      query = query.or(`name.ilike.%${searchTerm}%,phone.ilike.%${searchTerm}%,cpf.ilike.%${searchTerm}%`);
    } else {
      // If no search term, limit to most recent clients
      query = query.limit(10);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(error.message);
    }

    return data || [];
  },

  async createOrder(order: OrderInput): Promise<Order> {
    const session = await supabase.auth.getSession();
    if (!session.data.session) {
      throw new Error('User must be authenticated to create orders');
    }

    const { data: newOrder, error: orderError } = await supabase
      .from('orders')
      .insert([{
        client_id: order.client_id,
        plan: order.plan,
        pickup_date: order.pickup_date,
        pickup_time: order.pickup_time,
        return_date: order.return_date,
        return_time: order.return_time,
        total_amount: order.total_amount,
        payment_method: order.payment_method,
        notes: order.notes
      }])
      .select()
      .single();

    if (orderError) {
      throw new Error(orderError.message);
    }

    // Insert order items
    const orderItems = order.items.map(item => ({
      order_id: newOrder.id,
      item_id: item.item_id,
      quantity: item.quantity,
      unit_price: item.unit_price
    }));

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(orderItems);

    if (itemsError) {
      throw new Error(itemsError.message);
    }

    return newOrder;
  },

  async getOrders(searchTerm?: string, status?: string): Promise<Order[]> {
    let query = supabase
      .from('orders')
      .select(`
        *,
        client:clients(name),
        items:order_items(
          quantity,
          unit_price,
          item:inventory_items(*)
        )
      `)
      .order('created_at', { ascending: false });

    if (searchTerm) {
      query = query.or(`client.name.ilike.%${searchTerm}%,id.ilike.%${searchTerm}%`);
    }

    if (status) {
      query = query.eq('order_status', status);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(error.message);
    }

    return data;
  },

  async getOrderById(id: string): Promise<Order | null> {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        *,
        client:clients(*),
        items:order_items(
          quantity,
          unit_price,
          item:inventory_items(*)
        )
      `)
      .eq('id', id)
      .single();

    if (error) {
      throw new Error(error.message);
    }

    return data;
  },

  async updateOrder(id: string, order: OrderInput): Promise<Order> {
    // Delete existing items first
    await supabase
      .from('order_items')
      .delete()
      .eq('order_id', id);

    // Insert new items
    const orderItems = order.items.map(item => ({
      order_id: id,
      item_id: item.item_id,
      quantity: item.quantity,
      unit_price: item.unit_price
    }));

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(orderItems);

    if (itemsError) {
      throw new Error(itemsError.message);
    }

    // Update order details
    const { data, error } = await supabase
      .from('orders')
      .update({
        client_id: order.client_id,
        plan: order.plan,
        pickup_date: order.pickup_date,
        pickup_time: order.pickup_time,
        return_date: order.return_date,
        return_time: order.return_time,
        total_amount: order.total_amount,
        payment_method: order.payment_method,
        notes: order.notes,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new Error(error.message);
    }

    return data;
  },

  async cancelOrder(id: string): Promise<void> {
    const { error } = await supabase
      .rpc('cancel_order', { p_order_id: id });

    if (error) {
      throw new Error(`Failed to cancel order: ${error.message}`);
    }
  },

  async generateContract(orderId: string): Promise<string> {
    const { data: order, error } = await supabase
      .from('orders')
      .select(`
        *,
        client:clients(*),
        items:order_items(
          quantity,
          unit_price,
          item:inventory_items(
            name,
            category,
            acquisition_price
          )
        )
      `)
      .eq('id', orderId)
      .single();

    if (error) {
      throw new Error('Failed to fetch order details');
    }

    // Generate contract content
    const contractContent = `
CONTRATO DE LOCAÇÃO DE MATERIAIS

LOCADOR:
Cláudia Amélia Gonçalves
CPF: 330.897.318-94
End: Rua João Carlos Espíndola, 141 - Palhoça - SC

LOCATÁRIO:
${order.client.name}
CPF: ${order.client.cpf}
Endereço: ${order.client.address}, ${order.client.address_number} - ${order.client.neighborhood}
Contato: ${order.client.phone}

Data de Retirada: ${new Date(order.pickup_date).toLocaleDateString()} às ${order.pickup_time}
Data de Devolução: ${new Date(order.return_date).toLocaleDateString()} às ${order.return_time}
Valor total da locação: R$ ${order.total_amount.toFixed(2)}
Forma de pagamento: Via Pix (50% na reserva e o Restante na retirada)

CLÁUSULAS

1º Pelo presente contrato de locação, é dever do locador oferecer o serviço de locação ao locatário, respeitando dia e horário marcados;

2º É dever do locatário para locação durante a semana, respeitar o período de 24h de locação e para os finais de semana fica combinado que o locatário deverá retirar o kit na sexta-feira das 10h às 18h e realizar a devolução na segunda-feira das 10h às 18h. O DESCUMPRIMENTO DA DATA COMBINADA PARA A DEVOLUÇÃO ACARRETARÁ EM MULTA NO MESMO VALOR DA LOCAÇÃO (R$ 120,00), exceto se houver uma justificativa anterior;

3º O locatário deve ficar ciente de que, se não devolver o kit, será denunciado por furto pela empresa Festa Fantástica. Isso se dará através de uma ação pelo advogado da empresa, que usará o número do documento do locador, citado acima;

4º Durante o período de locação, fica o locatário responsável por qualquer dano causado aos objetos de decoração, estando portanto, ciente que deverá pagar taxas correspondentes aos danos e caso o material seja entregue sujo será cobrado;

5º MATERIAL LOCADO ENTREGUES COM AVARIAS/MANCHADOS OU QUEBRADOS SERÁ COBRADO O VALOR TOTAL NA ENTREGA DO MESMO:
${order.items.map(item => 
  `${item.item.name}: R$ ${item.item.acquisition_price?.toFixed(2) || 'N/A'}`
).join(' / ')}

6º O locatário deve estar ciente de que não pode utilizar nenhum tipo de cola nas capas de cilindros/painel ou em qualquer outro item do kit locado. Deve-se tomar cuidado com velas nas capas, pois pode queimá-las e estragá-las. Não colocar copos ou latas de bebidas em cima da mesa de cilindros pois pode molhar e estragar o MDF. Nossas boleiras e bandejas são de acrílico/plástico, se cair podem quebrar;

7º Os móveis e itens decorativos devem ficar em local coberto e seco;

8º Não é permitido retirar ou devolver o kit por aplicativo de entrega (Uber, 99, Lalamove), exceto se o cliente estiver presente;

9º Caso haja desistência o valor não será devolvido. Se avisado previamente, o valor pago ficará como crédito para uma próxima locação, sendo que para troca de data verificaremos se a data haverá disponibilidade.

10º DEPOIS DE FECHADO O CONTRATO NÃO PODERÁ ALTERAR O TEMA ESCOLHIDO.

Estou ciente do contrato que li e aceito.

Palhoça - SC, ${new Date().toLocaleDateString()}

_______________________          _______________________
        LOCADOR                        LOCATÁRIO
`;

    return contractContent;
  },

  generateContractPDF(order: Order & { client: Client; items: Array<{ item: InventoryItem; quantity: number; unit_price: number }> }): void {
    const doc = new jsPDF({
      format: 'a4',
      unit: 'mm',
      orientation: 'portrait'
    });

    // Set font
    doc.setFont('times', 'normal');
    doc.setFontSize(9);

    // Set margins
    const margin = 5;
    const pageWidth = doc.internal.pageSize.width;
    const pageHeight = doc.internal.pageSize.height;
    const contentWidth = pageWidth - (2 * margin);

    // Title
    doc.setFont('times', 'bold');
    doc.setFontSize(12);
    doc.text('CONTRATO DE LOCAÇÃO DE MATERIAIS', pageWidth / 2, margin + 5, { align: 'center' });

    // Reset font
    doc.setFont('times', 'normal');
    doc.setFontSize(9);

    // Locador info
    let yPos = margin + 15;
    doc.text('LOCADOR:', margin, yPos);
    yPos += 4;
    doc.text('Cláudia Amélia Gonçalves - CPF: 330.897.318-94', margin, yPos);
    yPos += 4;
    doc.text('End: Rua João Carlos Espíndola, 141 - Palhoça - SC', margin, yPos);

    // Locatário info
    yPos += 8;
    doc.text('LOCATÁRIO:', margin, yPos);
    yPos += 4;
    doc.text(`${order.client.name} - CPF: ${order.client.cpf}`, margin, yPos);
    yPos += 4;
    doc.text(`Endereço: ${order.client.address}, ${order.client.address_number} - ${order.client.neighborhood}`, margin, yPos);
    yPos += 4;
    doc.text(`Contato: ${order.client.phone}`, margin, yPos);

    // Dates and payment info
    yPos += 8;
    doc.text(`Data de Retirada: ${new Date(order.pickup_date).toLocaleDateString()} às ${order.pickup_time}`, margin, yPos);
    yPos += 4;
    doc.text(`Data de Devolução: ${new Date(order.return_date).toLocaleDateString()} às ${order.return_time}`, margin, yPos);
    yPos += 4;
    doc.text(`Valor total da locação: R$ ${order.total_amount.toFixed(2)}`, margin, yPos);
    yPos += 4;
    doc.text('Forma de pagamento: Via Pix (50% na reserva e o Restante na retirada)', margin, yPos);

    // Clauses
    yPos += 8;
    doc.setFont('times', 'bold');
    doc.text('CLÁUSULAS', margin, yPos);
    doc.setFont('times', 'normal');

    const clauses = [
      'Pelo presente contrato de locação, é dever do locador oferecer o serviço de locação ao locatário, respeitando dia e horário marcados;',
      'É dever do locatário para locação durante a semana, respeitar o período de 24h de locação e para os finais de semana fica combinado que o locatário deverá retirar o kit na sexta-feira das 10h às 18h e realizar a devolução na segunda-feira das 10h às 18h. O DESCUMPRIMENTO DA DATA COMBINADA PARA A DEVOLUÇÃO ACARRETARÁ EM MULTA NO MESMO VALOR DA LOCAÇÃO (R$ 120,00), exceto se houver uma justificativa anterior;',
      'O locatário deve ficar ciente de que, se não devolver o kit, será denunciado por furto pela empresa Festa Fantástica. Isso se dará através de uma ação pelo advogado da empresa, que usará o número do documento do locador, citado acima;',
      'Durante o período de locação, fica o locatário responsável por qualquer dano causado aos objetos de decoração, estando portanto, ciente que deverá pagar taxas correspondentes aos danos e caso o material seja entregue sujo será cobrado;',
      `MATERIAL LOCADO ENTREGUES COM AVARIAS/MANCHADOS OU QUEBRADOS SERÁ COBRADO O VALOR TOTAL NA ENTREGA DO MESMO:\n${order.items.map(item => 
        `${item.item.name}: R$ ${item.item.acquisition_price?.toFixed(2) || 'N/A'}`
      ).join(' / ')}`,
      'O locatário deve estar ciente de que não pode utilizar nenhum tipo de cola nas capas de cilindros/painel ou em qualquer outro item do kit locado. Deve-se tomar cuidado com velas nas capas, pois pode queimá-las e estragá-las. Não colocar copos ou latas de bebidas em cima da mesa de cilindros pois pode molhar e estragar o MDF. Nossas boleiras e bandejas são de acrílico/plástico, se cair podem quebrar;',
      'Os móveis e itens decorativos devem ficar em local coberto e seco;',
      'Não é permitido retirar ou devolver o kit por aplicativo de entrega (Uber, 99, Lalamove), exceto se o cliente estiver presente;',
      'Caso haja desistência o valor não será devolvido. Se avisado previamente, o valor pago ficará como crédito para uma próxima locação, sendo que para troca de data verificaremos se a data haverá disponibilidade.',
      'DEPOIS DE FECHADO O CONTRATO NÃO PODERÁ ALTERAR O TEMA ESCOLHIDO.'
    ];

    yPos += 8;
    clauses.forEach((clause, index) => {
      doc.text(`${index + 1}º ${clause}`, margin, yPos, {
        maxWidth: contentWidth,
        align: 'justify'
      });
      const textHeight = doc.getTextDimensions(clause, { maxWidth: contentWidth }).h;
      yPos += textHeight + 4;
    });

    // Acceptance and signatures
    yPos += 8;
    doc.text('Estou ciente do contrato que li e aceito.', margin, yPos);
    yPos += 8;
    doc.text(`Palhoça - SC, ${new Date().toLocaleDateString()}`, margin, yPos);
    yPos += 16;
    doc.text('_______________________          _______________________', margin, yPos);
    yPos += 4;
    doc.text('        LOCADOR                        LOCATÁRIO', margin, yPos);

    // Save the PDF with the client's name
    const fileName = `contrato-${order.client.name.toLowerCase().replace(/\s+/g, '-')}.pdf`;
    doc.save(fileName);
  },

  async getInventoryItems(searchTerm?: string): Promise<InventoryItem[]> {
    let query = supabase
      .from('inventory_items')
      .select('*')
      .eq('status', 'active')
      .gt('current_stock', 0)
      .order('name');

    if (searchTerm) {
      query = query.or(`name.ilike.%${searchTerm}%,code.ilike.%${searchTerm}%`);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(error.message);
    }

    return data || [];
  }
};