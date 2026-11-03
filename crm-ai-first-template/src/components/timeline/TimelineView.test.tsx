import {render,screen,fireEvent,cleanup} from '@testing-library/react';
import {afterEach,it,expect} from 'vitest';
import {TimelineView} from './TimelineView';
afterEach(cleanup);
it('abre respostas formatadas do envio por clique e teclado, sem mostrar JSON',()=>{
 const event={id:'form-submission-1',type:'form_submission',team:'sales',date:'2026-09-10T19:00:00Z',title:'Formulário preenchido',description:'Página da Imersão',metadata:{answers:{nome:'Contato de teste',faturamento:18000,aceita_contato:false,contato:{email:'teste@example.invalid'}}}};
 render(<TimelineView timeline={[event]}/>);
 fireEvent.keyDown(screen.getByRole('button',{name:'Ver respostas: Página da Imersão'}),{key:'Enter'});
 expect(screen.getByRole('dialog')).toBeInTheDocument();
 expect(screen.getByText('18.000')).toBeInTheDocument();expect(screen.getByText('Não')).toBeInTheDocument();expect(screen.getByText('teste@example.invalid')).toBeInTheDocument();
 fireEvent.click(screen.getByRole('button',{name:'Close'}));
 fireEvent.click(screen.getByRole('button',{name:'Ver respostas: Página da Imersão'}));expect(screen.getByRole('dialog')).toBeInTheDocument();
});
